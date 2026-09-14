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
                let status = await authorizationStatus()
                guard !enabled else { return }
                if status == .denied {
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
                let status = await authorizationStatus()
                let allowed: Bool
                if status == .notDetermined {
                    allowed = try await requestAuthorization()
                } else {
                    allowed = status == .authorized || status == .provisional
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
        let status = await authorizationStatus()
        guard change == revision, enabled else { return }
        guard status == .authorized || status == .provisional else {
            statusText = "Allow notifications in System Settings."
            return
        }
        let now = Date()
        let reminders = Array(ResetReminderPlanner.reminders(for: inventory, now: now).prefix(32))
        let activeIDs = Set(reminders.map(\.identifier))
        let pending = await pendingIdentifiers()
        let delivered = await deliveredIdentifiers()
        guard change == revision, enabled else { return }
        let ownedIDs = Set(pending + delivered)
            .filter { $0.hasPrefix(ResetReminderPlanner.identifierPrefix) }
        let removed = Array(ownedIDs.subtracting(activeIDs))
        center.removePendingNotificationRequests(withIdentifiers: removed)
        center.removeDeliveredNotifications(withIdentifiers: removed)
        scheduledDates = scheduledDates.filter { activeIDs.contains($0.key) }
        let deliveredIDs = Set(delivered)

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
                try await addNotification(request)
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

    // Older SDKs do not mark notification objects Sendable. Extract immutable
    // values before resuming on the main actor. Explicit Sendable callbacks also
    // prevent legacy signatures from inferring main-actor execution off-thread.
    private func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { @Sendable settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { @Sendable requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private func deliveredIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { @Sendable notifications in
                continuation.resume(returning: notifications.map { $0.request.identifier })
            }
        }
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { @Sendable allowed, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: allowed)
                }
            }
        }
    }

    private func addNotification(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            center.add(request) { @Sendable error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func removeOwnedNotifications() async {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let pending = await pendingIdentifiers()
        let delivered = await deliveredIdentifiers()
        let identifiers = (pending + delivered)
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
