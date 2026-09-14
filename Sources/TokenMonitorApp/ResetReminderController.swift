import AppKit
import Combine
import Foundation
import TokenMonitorCore
import UserNotifications

@MainActor
final class ResetReminderController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private static let enabledKey = "bankedResetRemindersEnabled"
    private static let scheduledKey = "bankedResetReminderSchedule"
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: enabledKey)
    @Published private(set) var statusText = "Notify 3 days before expiry."
    private lazy var center = UNUserNotificationCenter.current()
    private var inventory: BankedResetInventory?
    private var revision = 0
    private var authorizationGeneration = 0
    private var work: Task<Void, Never>?
    private var scheduledDates: [String: Double] = UserDefaults.standard.dictionary(forKey: scheduledKey) as? [String: Double] ?? [:]

    func start() {
        guard Bundle.main.bundleIdentifier != nil else {
            enabled = false
            statusText = "Run the installed app to enable reminders."
            return
        }
        center.delegate = self
        if enabled {
            setEnabled(true)
        } else {
            Task {
                let settings = await center.notificationSettings()
                guard !enabled else { return }
                if settings.authorizationStatus == .denied {
                    statusText = "Allow notifications in System Settings."
                }
            }
        }
    }

    func setEnabled(_ value: Bool) {
        guard Bundle.main.bundleIdentifier != nil else {
            enabled = false
            statusText = "Run the installed app to enable reminders."
            return
        }
        revision += 1
        authorizationGeneration += 1
        let change = authorizationGeneration
        enabled = value
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        if !value {
            statusText = "Notify 3 days before expiry."
            enqueue {
                await self.removeOwnedNotifications()
                let now = Date().timeIntervalSince1970
                self.scheduledDates = self.scheduledDates.filter { $0.value <= now }
                self.persistSchedule()
            }
            return
        }
        Task {
            do {
                let settings = await center.notificationSettings()
                let allowed: Bool
                if settings.authorizationStatus == .notDetermined {
                    allowed = try await center.requestAuthorization(options: [.alert, .sound])
                } else {
                    allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                }
                guard change == authorizationGeneration, enabled else { return }
                if !allowed {
                    enabled = false
                    UserDefaults.standard.set(false, forKey: Self.enabledKey)
                    statusText = "Allow notifications in System Settings."
                    return
                }
                statusText = "Notify 3 days before expiry."
                enqueueReconciliation()
            } catch {
                guard change == authorizationGeneration else { return }
                enabled = false
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                statusText = "Notifications unavailable. Try enabling again."
            }
        }
    }

    func update(_ value: BankedResetInventory?) {
        // Missing/loading data must not erase existing expiry reminders.
        guard let value else { return }
        revision += 1
        inventory = value
        enqueueReconciliation()
    }

    func disconnect() {
        revision += 1
        authorizationGeneration += 1
        inventory = nil
        enqueue {
            await self.removeOwnedNotifications()
            self.scheduledDates = [:]
            self.persistSchedule()
        }
    }

    private func enqueue(_ action: @escaping @MainActor () async -> Void) {
        let previous = work
        work = Task {
            await previous?.value
            await action()
        }
    }

    private func enqueueReconciliation() {
        enqueue { await self.reconcile() }
    }

    private func reconcile() async {
        guard Bundle.main.bundleIdentifier != nil, enabled, let inventory else { return }
        let change = revision
        let settings = await center.notificationSettings()
        guard change == revision, enabled else { return }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            statusText = "Allow notifications in System Settings."
            return
        }
        let now = Date()
        let reminders = Array(ResetReminderPlanner.reminders(for: inventory, now: now).prefix(32))
        let activeIDs = Set(reminders.map(\.identifier))
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        guard change == revision, enabled else { return }
        let ownedIDs = Set(pending.map(\.identifier) + delivered.map { $0.request.identifier })
            .filter { $0.hasPrefix(ResetReminderPlanner.identifierPrefix) }
        let removed = Array(ownedIDs.subtracting(activeIDs))
        center.removePendingNotificationRequests(withIdentifiers: removed)
        center.removeDeliveredNotifications(withIdentifiers: removed)
        scheduledDates = scheduledDates.filter { activeIDs.contains($0.key) }
        let deliveredIDs = Set(delivered.map { $0.request.identifier })

        for reminder in reminders {
            guard change == revision, enabled else { return }
            let previous = scheduledDates[reminder.identifier].map(Date.init(timeIntervalSince1970:))
            guard ResetReminderPlanner.shouldSchedule(reminder, previousFireDate: previous, delivered: deliveredIDs.contains(reminder.identifier), now: now) else { continue }
            let content = UNMutableNotificationContent()
            content.title = reminder.count == 1 ? "A banked reset expires soon" : "\(reminder.count) banked resets expire soon"
            let date = DateFormatter()
            date.locale = Locale(identifier: "en_US_POSIX")
            date.dateFormat = "MMM d, HH:mm"
            content.body = "ChatGPT: expires \(date.string(from: reminder.expiresAt)). Review your saved resets before they expire."
            content.sound = .default
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireAt)
            components.timeZone = calendar.timeZone
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                guard change == revision, enabled else {
                    center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
                    return
                }
                scheduledDates[reminder.identifier] = reminder.fireAt.timeIntervalSince1970
                persistSchedule()
            } catch {
                statusText = "Could not schedule a reminder. Try again."
            }
        }
        persistSchedule()
    }

    private func persistSchedule() {
        UserDefaults.standard.set(scheduledDates, forKey: Self.scheduledKey)
    }

    private func removeOwnedNotifications() async {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let identifiers = (pending.map(\.identifier) + delivered.map { $0.request.identifier })
            .filter { $0.hasPrefix(ResetReminderPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier.hasPrefix(ResetReminderPlanner.identifierPrefix) else { return }
        await MainActor.run {
            AppModel.shared.openLogin(for: .chatGPT)
        }
    }
}
