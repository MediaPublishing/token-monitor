import AppKit
import Combine
import Foundation
import TokenMonitorCore
import UserNotifications

@MainActor
final class ResetReminderController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private static let enabledKey = "bankedResetRemindersEnabled"
    private static let scheduledKey = "bankedResetReminderSchedule"
    @Published private(set) var enabled = false
    @Published private(set) var statusText = "Notify 3 days before expiry."
    @Published private(set) var authorizationState: UNAuthorizationStatus = .notDetermined
    @Published private(set) var schedulingError: String?
    @Published private(set) var requestingAuthorization = false
    private var requestedEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    private var activationSubscription: AnyCancellable?
    private lazy var center = UNUserNotificationCenter.current()
    private var inventories: [UUID: (name: String, inventory: BankedResetInventory?)] = [:]
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
        activationSubscription = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAuthorization() }
        refreshAuthorization()
    }

    func refreshAuthorization() {
        guard !requestingAuthorization else { return }
        let generation = authorizationGeneration
        Task {
            let status = await authorizationStatus()
            guard generation == authorizationGeneration, !requestingAuthorization else { return }
            authorizationState = status
            enabled = requestedEnabled && isAuthorized(status)
            updateStatus()
            if enabled { enqueueReconciliation() }
        }
    }

    func openNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
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
        requestedEnabled = value
        schedulingError = nil
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        if !value {
            enabled = false
            requestingAuthorization = false
            statusText = "Notify 3 days before expiry."
            enqueue {
                await self.removeOwnedNotifications()
                let now = Date().timeIntervalSince1970
                self.scheduledDates = self.scheduledDates.filter { $0.value <= now }
                self.persistSchedule()
            }
            return
        }
        requestingAuthorization = true
        statusText = "Checking notification permission..."
        let generation = authorizationGeneration
        Task { await requestOnExplicitEnable(generation: generation) }
    }

    func update(_ value: BankedResetInventory?, accountID: UUID, accountName: String) {
        // Missing/loading data must not erase existing expiry reminders.
        revision += 1
        inventories[accountID] = (accountName, value ?? inventories[accountID]?.inventory)
        enqueueReconciliation()
    }

    func disconnect(accountID: UUID) {
        revision += 1
        inventories.removeValue(forKey: accountID)
        enqueue {
            let prefix = ResetReminderPlanner.identifierPrefix + accountID.uuidString + "-"
            let pending = await self.pendingIdentifiers()
            let delivered = await self.deliveredIdentifiers()
            let identifiers = (pending + delivered).filter {
                $0.hasPrefix(prefix) || (accountID == ServiceKind.chatGPT.dataStoreIdentifier && self.isLegacyIdentifier($0))
            }
            self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            self.center.removeDeliveredNotifications(withIdentifiers: identifiers)
            self.scheduledDates = self.scheduledDates.filter {
                !$0.key.hasPrefix(prefix) && !(accountID == ServiceKind.chatGPT.dataStoreIdentifier && self.isLegacyIdentifier($0.key))
            }
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
        let change = revision
        enqueue {
            guard change == self.revision else { return }
            await self.reconcile()
        }
    }

    private func reconcile() async {
        guard Bundle.main.bundleIdentifier != nil, enabled else { return }
        let change = revision
        let status = await authorizationStatus()
        guard change == revision, enabled else { return }
        authorizationState = status
        guard isAuthorized(status) else {
            enabled = false
            updateStatus()
            return
        }
        let now = Date()
        var allReminders: [ResetReminder] = []
        for (accountID, entry) in inventories {
            guard let inventory = entry.inventory else { continue }
            allReminders.append(contentsOf: ResetReminderPlanner.reminders(for: inventory, now: now, accountID: accountID))
        }
        allReminders.sort {
            $0.expiresAt == $1.expiresAt ? $0.identifier < $1.identifier : $0.expiresAt < $1.expiresAt
        }
        let reminders = Array(allReminders.prefix(32))
        let activeIDs = Set(reminders.map(\.identifier))
        let pending = await pendingIdentifiers()
        let delivered = await deliveredIdentifiers()
        guard change == revision, enabled else { return }
        let primaryID = ServiceKind.chatGPT.dataStoreIdentifier
        let primaryKnown = inventories[primaryID]?.inventory != nil
        let activeLegacyIDs = Set(reminders.filter { ResetReminderPlanner.accountID(from: $0.identifier) == primaryID }
            .map { ResetReminderPlanner.identifier(for: $0.expiresAt) })
        // Unknown inventories preserve pending reminders; confirmed zero removes only that account.
        let removed = Set(pending + delivered).filter { identifier in
            guard identifier.hasPrefix(ResetReminderPlanner.identifierPrefix) else { return false }
            if let accountID = ResetReminderPlanner.accountID(from: identifier) {
                return !activeIDs.contains(identifier) && (inventories[accountID] == nil || inventories[accountID]?.inventory != nil)
            }
            return primaryKnown && !activeLegacyIDs.contains(identifier)
        }
        center.removePendingNotificationRequests(withIdentifiers: Array(removed))
        center.removeDeliveredNotifications(withIdentifiers: Array(removed))
        scheduledDates = scheduledDates.filter {
            if let accountID = ResetReminderPlanner.accountID(from: $0.key) {
                return activeIDs.contains($0.key) || inventories[accountID]?.inventory == nil && inventories[accountID] != nil
            }
            return !primaryKnown || activeLegacyIDs.contains($0.key)
        }
        let deliveredIDs = Set(delivered)
        let pendingIDs = Set(pending)
        schedulingError = nil

        for reminder in reminders {
            guard change == revision, enabled else { return }
            guard let accountID = ResetReminderPlanner.accountID(from: reminder.identifier) else { continue }
            let legacyID = ResetReminderPlanner.identifier(for: reminder.expiresAt)
            let legacyDate = accountID == primaryID ? scheduledDates[legacyID] : nil
            let previous = (scheduledDates[reminder.identifier] ?? legacyDate).map(Date.init(timeIntervalSince1970:))
            let deliveredBefore = deliveredIDs.contains(reminder.identifier) || (accountID == primaryID && deliveredIDs.contains(legacyID))
            guard ResetReminderPlanner.shouldSchedule(reminder, previousFireDate: previous, delivered: deliveredBefore, now: now) else {
                if deliveredBefore || previous.map({ $0 <= now }) == true {
                    scheduledDates[reminder.identifier] = previous?.timeIntervalSince1970 ?? now.timeIntervalSince1970
                }
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = reminder.count == 1 ? "A banked reset expires soon" : "\(reminder.count) banked resets expire soon"
            let date = DateFormatter()
            date.locale = Locale(identifier: "en_US_POSIX")
            date.dateFormat = "MMM d, HH:mm"
            content.body = "\(inventories[accountID]?.name ?? "ChatGPT"): expires \(date.string(from: reminder.expiresAt)). Review your saved resets before they expire."
            content.userInfo = ["accountID": accountID.uuidString]
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
                if accountID == primaryID && pendingIDs.contains(legacyID) {
                    center.removePendingNotificationRequests(withIdentifiers: [legacyID])
                    scheduledDates.removeValue(forKey: legacyID)
                }
                persistSchedule()
            } catch {
                let error = error as NSError
                schedulingError = "\(error.domain) \(error.code)"
                statusText = "Could not schedule a reminder. Try again."
            }
        }
        persistSchedule()
        updateStatus()
    }

    private func requestOnExplicitEnable(generation: Int) async {
        do {
            var status = await authorizationStatus()
            guard generation == authorizationGeneration, requestedEnabled else { return }
            if status == .notDetermined {
                _ = try await requestAuthorization()
                status = await authorizationStatus()
            }
            guard generation == authorizationGeneration, requestedEnabled else { return }
            authorizationState = status
            enabled = isAuthorized(status)
            requestingAuthorization = false
            updateStatus()
            if enabled { enqueueReconciliation() }
        } catch {
            guard generation == authorizationGeneration else { return }
            enabled = false
            requestingAuthorization = false
            let error = error as NSError
            schedulingError = "\(error.domain) \(error.code)"
            statusText = "Notifications unavailable. Try again."
        }
    }

    private func updateStatus() {
        if schedulingError != nil { statusText = "Notifications unavailable. Try again."; return }
        switch authorizationState {
        case .denied: statusText = "Notifications are blocked. Open Notification Settings."
        case .notDetermined: statusText = "Notify 3 days before expiry."
        case .authorized, .provisional:
            let knownDates = inventories.values.contains { $0.inventory?.availableGroups(at: Date()).contains { $0.expiresAt != nil } == true }
            statusText = enabled && !knownDates ? "No expiry date available yet." : "Notify 3 days before expiry."
        @unknown default: statusText = "Notification status unavailable."
        }
    }

    private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    private func isLegacyIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(ResetReminderPlanner.identifierPrefix) && ResetReminderPlanner.accountID(from: identifier) == nil
    }

    var diagnosticsText: String {
        "Notifications: \(authorizationState.rawValue)\nReminders requested: \(requestedEnabled)\nReminders enabled: \(enabled)\nReminder error: \(schedulingError ?? "none")"
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
        let accountID = (response.notification.request.content.userInfo["accountID"] as? String).flatMap(UUID.init(uuidString:))
            ?? ResetReminderPlanner.accountID(from: response.notification.request.identifier)
            ?? ServiceKind.chatGPT.dataStoreIdentifier
        await MainActor.run {
            AppModel.shared.openLogin(accountID: accountID)
        }
    }
}
