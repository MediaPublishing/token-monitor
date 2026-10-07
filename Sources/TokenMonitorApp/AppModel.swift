import AppKit
import Combine
import Foundation
import ServiceManagement
import TokenMonitorCore

enum PopoverScreen {
    case dashboard
    case settings
}

enum StatusMenuLimitDisplay: String, CaseIterable, Identifiable {
    case session
    case total
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session:
            return "Session"
        case .total:
            return "Total"
        case .both:
            return "Both"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private enum Keys {
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let debugModeEnabled = "debugModeEnabled"
        static let statusMenuUsesColor = "statusMenuUsesColor"
        static let statusMenuShowsPercentages = "statusMenuShowsPercentages"
        static let statusMenuLimitDisplay = "statusMenuLimitDisplay"
        static let showUsageDetails = "showUsageDetails"
        static let openCodeGoEnabled = "openCodeGoEnabled"
        static let menuBarAccountIDs = "menuBarAccountIDs"
    }

    @Published private(set) var dashboardState: DashboardState
    @Published private(set) var accounts: [MonitoredAccount]
    @Published private(set) var menuBarAccountIDs: [String: String]
    @Published private(set) var popoverScreen: PopoverScreen = .dashboard
    @Published private(set) var isPopoverVisible = false
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var debugModeEnabled: Bool
    @Published private(set) var statusMenuUsesColor: Bool
    @Published private(set) var statusMenuShowsPercentages: Bool
    @Published private(set) var statusMenuLimitDisplay: StatusMenuLimitDisplay
    @Published private(set) var showUsageDetails: Bool
    @Published private(set) var openCodeGoEnabled: Bool

    let snapshotDirectoryURL: URL
    let diagnosticsDirectoryURL: URL
    let resetReminders = ResetReminderController()

    private let snapshotStore: SnapshotPersisting
    private let accountStore: AccountPersisting
    private let canPersistAccounts: Bool
    private let diagnosticsStore: DiagnosticsStore
    private let sessionCoordinator: SessionCoordinator
    private let updateController: AppUpdateController
    private var refreshTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingForcedRefreshes: [UUID: RefreshTrigger] = [:]
    private var backgroundRefreshTimer: Timer?

    init(
        snapshotStore: SnapshotPersisting = FileSnapshotStore(),
        accountStore: AccountPersisting = FileAccountStore(),
        updateController: AppUpdateController = .shared
    ) {
        self.snapshotStore = snapshotStore
        self.accountStore = accountStore
        self.updateController = updateController
        UserDefaults.standard.register(defaults: [
            Keys.launchAtLoginEnabled: true,
            Keys.debugModeEnabled: false,
            Keys.statusMenuUsesColor: true,
            Keys.statusMenuShowsPercentages: false,
            Keys.statusMenuLimitDisplay: StatusMenuLimitDisplay.total.rawValue,
            Keys.showUsageDetails: false,
            Keys.openCodeGoEnabled: false
        ])
        launchAtLoginEnabled = UserDefaults.standard.bool(forKey: Keys.launchAtLoginEnabled)
        let initialDebugModeEnabled = UserDefaults.standard.bool(forKey: Keys.debugModeEnabled)
        debugModeEnabled = initialDebugModeEnabled
        statusMenuUsesColor = UserDefaults.standard.bool(forKey: Keys.statusMenuUsesColor)
        statusMenuShowsPercentages = UserDefaults.standard.bool(forKey: Keys.statusMenuShowsPercentages)
        statusMenuLimitDisplay = StatusMenuLimitDisplay(
            rawValue: UserDefaults.standard.string(forKey: Keys.statusMenuLimitDisplay) ?? ""
        ) ?? .total
        showUsageDetails = UserDefaults.standard.bool(forKey: Keys.showUsageDetails)
        openCodeGoEnabled = UserDefaults.standard.bool(forKey: Keys.openCodeGoEnabled)
        menuBarAccountIDs = UserDefaults.standard.dictionary(forKey: Keys.menuBarAccountIDs) as? [String: String] ?? [:]
        automaticallyChecksForUpdates = updateController.automaticallyChecksForUpdates
        let snapshots = (try? snapshotStore.loadSnapshots()) ?? [:]
        let savedAccounts = try? accountStore.loadAccounts()
        canPersistAccounts = savedAccounts != nil
        let restoredAccounts = AccountMigration.restoring(savedAccounts ?? [], legacySnapshots: snapshots)
        accounts = restoredAccounts
        dashboardState = DashboardState.initial(accounts: restoredAccounts)

        if let fileStore = snapshotStore as? FileSnapshotStore {
            snapshotDirectoryURL = fileStore.directoryURL
        } else {
            snapshotDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/TokenMonitor", isDirectory: true)
        }
        diagnosticsStore = DiagnosticsStore(baseDirectory: snapshotDirectoryURL, isEnabled: initialDebugModeEnabled)
        diagnosticsDirectoryURL = snapshotDirectoryURL.appendingPathComponent("Debug", isDirectory: true)
        sessionCoordinator = SessionCoordinator(diagnosticsStore: diagnosticsStore, accounts: restoredAccounts)
        if canPersistAccounts {
            do {
                try accountStore.saveAccounts(restoredAccounts)
            } catch {
                NSLog("Failed to initialize account registry: \(error.localizedDescription)")
            }
        } else {
            NSLog("Account registry could not be loaded; leaving its existing file untouched")
        }
    }

    func start() {
        guard backgroundRefreshTimer == nil else {
            return
        }

        syncLaunchAtLoginRegistration()
        resetReminders.start()

        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPopoverVisible else {
                    return
                }
                self.refreshAll(trigger: .background)
            }
        }

        refreshAll(trigger: .launch)
    }

    func didOpenPopover() {
        isPopoverVisible = true
        popoverScreen = .dashboard
    }

    func didClosePopover() {
        isPopoverVisible = false
        popoverScreen = .dashboard
    }

    func showSettingsInPopover() {
        popoverScreen = .settings
    }

    func showDashboardInPopover() {
        popoverScreen = .dashboard
    }

    func refreshAll(trigger: RefreshTrigger) {
        for account in enabledAccounts {
            refresh(account.id, trigger: trigger, force: trigger == .manual)
        }
    }

    var dashboardServices: [ServiceStatus] {
        let order: [ServiceKind] = [.chatGPT, .claude, .openCodeGo]
        return order.flatMap { service in
            dashboardState.services.filter { status in
                status.service == service &&
                (service != .openCodeGo || (openCodeGoEnabled && (status.snapshot != nil || !status.isPrimary)))
            }
        }
    }

    func providerSettingsServices(for service: ServiceKind) -> [ServiceStatus] {
        dashboardState.services.filter { $0.service == service }
    }

    var statusMenuServices: [ServiceKind] {
        var services: [ServiceKind] = [.chatGPT, .claude]
        if openCodeGoEnabled {
            services.append(.openCodeGo)
        }
        return services
    }

    var isRefreshing: Bool {
        !refreshTasks.isEmpty
    }

    func refresh(_ service: ServiceKind, trigger: RefreshTrigger, force: Bool = false) {
        refresh(service.dataStoreIdentifier, trigger: trigger, force: force)
    }

    func refresh(_ accountID: UUID, trigger: RefreshTrigger, force: Bool = false) {
        guard let status = dashboardState.account(accountID) else { return }
        let service = status.service
        guard service != .openCodeGo || openCodeGoEnabled else {
            return
        }

        if refreshTasks[accountID] != nil {
            if force {
                pendingForcedRefreshes[accountID] = trigger
            }
            return
        }

        if shouldSkipAutomaticRefresh(for: accountID, trigger: trigger) {
            return
        }

        DashboardReducer.reduce(&dashboardState, event: .account(accountID, .refreshStarted(trigger: trigger)))

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                Task { @MainActor in
                    self.refreshTasks[accountID] = nil
                    if let pendingTrigger = self.pendingForcedRefreshes.removeValue(forKey: accountID) {
                        self.refresh(accountID, trigger: pendingTrigger)
                    }
                }
            }

            do {
                let snapshot = try await sessionCoordinator.refresh(accountID: accountID)
                try Task.checkCancellation()
                await MainActor.run {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .account(accountID, .refreshSucceeded(snapshot))
                    )
                    self.persistSnapshots()
                    if service == .chatGPT && accountID == ServiceKind.chatGPT.dataStoreIdentifier {
                        self.resetReminders.update(snapshot.bankedResets)
                    }
                }
            } catch let parseError as UsageParseError {
                await MainActor.run {
                    self.applyParseError(parseError, for: accountID)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .account(accountID, .refreshFailed(message: self.userVisibleMessage(for: error)))
                    )
                }
            }
        }

        refreshTasks[accountID] = task
    }

    func openLogin(for service: ServiceKind, replacingExistingSession: Bool = false) {
        openLogin(accountID: service.dataStoreIdentifier, replacingExistingSession: replacingExistingSession)
    }

    func openLogin(accountID: UUID, replacingExistingSession: Bool = false) {
        guard let account = accounts.first(where: { $0.id == accountID }) else { return }
        let service = account.service
        // Connecting an optional provider also opts it into refreshes and the menu.
        if service == .openCodeGo && !openCodeGoEnabled {
            setOpenCodeGoEnabledWithoutRefreshing(true)
        }
        sessionCoordinator.cancelRefresh(accountID: accountID)

        if replacingExistingSession {
            refreshTasks[accountID]?.cancel()
            if service == .chatGPT && accountID == ServiceKind.chatGPT.dataStoreIdentifier { resetReminders.disconnect() }
            DashboardReducer.reduce(
                &dashboardState,
                event: .account(accountID, .disconnected(message: "Connect account"))
            )
            persistSnapshots()
        }

        DashboardReducer.reduce(&dashboardState, event: .account(accountID, .refreshStarted(trigger: .login)))
        sessionCoordinator.showLoginWindow(
            for: accountID,
            replacingExistingSession: replacingExistingSession,
            onAuthenticated: { [weak self] in
                self?.refresh(accountID, trigger: .login, force: true)
            },
            onDismissed: { [weak self] in
                guard let self else {
                    return
                }
                if case .refreshing(trigger: .login) = self.dashboardState.account(accountID)?.refreshState {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .account(accountID, .refreshFailed(message: "Reconnect window closed before a successful refresh"))
                    )
                }
            }
        )
    }

    func switchAccount(for service: ServiceKind) {
        openLogin(for: service, replacingExistingSession: true)
    }

    func disconnect(_ service: ServiceKind) {
        disconnect(accountID: service.dataStoreIdentifier)
    }

    func disconnect(accountID: UUID) {
        guard let account = accounts.first(where: { $0.id == accountID }) else { return }
        let service = account.service
        if service == .chatGPT && accountID == ServiceKind.chatGPT.dataStoreIdentifier { resetReminders.disconnect() }
        pendingForcedRefreshes[accountID] = nil
        refreshTasks[accountID]?.cancel()
        sessionCoordinator.cancelRefresh(accountID: accountID)

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.sessionCoordinator.clearSession(for: accountID)
            if service == .openCodeGo && self.accounts.filter({ $0.service == .openCodeGo }).count == 1 {
                self.setOpenCodeGoEnabledWithoutRefreshing(false)
            }
            DashboardReducer.reduce(
                &self.dashboardState,
                event: .account(accountID, .disconnected(message: "Connect account"))
            )
            self.persistSnapshots()
        }
    }

    func addAccount(for service: ServiceKind) {
        guard canPersistAccounts else { return }
        let count = accounts.filter { $0.service == service }.count
        let account = MonitoredAccount(id: UUID(), service: service,
                                       name: "\(service.displayName) \(count + 1)", isPrimary: false)
        accounts.append(account)
        dashboardState = DashboardState(services: dashboardState.services + [
            ServiceStatus(service: service, snapshot: nil,
                          refreshState: .authRequired(message: "Connect account"),
                          accountID: account.id, accountName: account.name, isPrimary: false)
        ])
        sessionCoordinator.add(account, diagnosticsStore: diagnosticsStore)
        if service == .openCodeGo { setOpenCodeGoEnabledWithoutRefreshing(true) }
        persistSnapshots()
        openLogin(accountID: account.id)
    }

    func renameAccount(_ accountID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40,
              let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[index].name = trimmed
        if let statusIndex = dashboardState.services.firstIndex(where: { $0.accountID == accountID }) {
            dashboardState.services[statusIndex].accountName = trimmed
        }
        persistSnapshots()
    }

    func removeAccount(_ accountID: UUID) {
        guard let account = accounts.first(where: { $0.id == accountID }), !account.isPrimary else { return }
        pendingForcedRefreshes[accountID] = nil
        refreshTasks[accountID]?.cancel()
        sessionCoordinator.cancelRefresh(accountID: accountID)
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.sessionCoordinator.remove(accountID)
            self.accounts.removeAll { $0.id == accountID }
            self.dashboardState.services.removeAll { $0.accountID == accountID }
            if self.menuBarAccountIDs[account.service.rawValue] == accountID.uuidString {
                self.setMenuBarAccount(account.service.dataStoreIdentifier, for: account.service)
            }
            if account.service == .openCodeGo && self.accounts.filter({ $0.service == .openCodeGo }).count == 1,
               self.dashboardState.service(.openCodeGo).snapshot == nil {
                self.setOpenCodeGoEnabledWithoutRefreshing(false)
            }
            self.persistSnapshots()
        }
    }

    func menuBarAccountID(for service: ServiceKind) -> UUID {
        guard let raw = menuBarAccountIDs[service.rawValue], let id = UUID(uuidString: raw),
              accounts.contains(where: { $0.id == id && $0.service == service }) else {
            return service.dataStoreIdentifier
        }
        return id
    }

    func setMenuBarAccount(_ accountID: UUID, for service: ServiceKind) {
        guard accounts.contains(where: { $0.id == accountID && $0.service == service }) else { return }
        menuBarAccountIDs[service.rawValue] = accountID.uuidString
        UserDefaults.standard.set(menuBarAccountIDs, forKey: Keys.menuBarAccountIDs)
    }

    func openUsagePageInDefaultBrowser(for service: ServiceKind) {
        NSWorkspace.shared.open(service.usageURL)
    }

    func desiredPopoverHeight() -> CGFloat {
        switch popoverScreen {
        case .dashboard:
            let visible = dashboardServices.count
            return min(760, (showUsageDetails ? 650 : 540) + 32 + CGFloat(max(0, visible - 3)) * 150)
        case .settings:
            return 700
        }
    }

    func quitApplication() {
        NSApp.terminate(nil)
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        guard launchAtLoginEnabled != enabled else {
            return
        }

        launchAtLoginEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.launchAtLoginEnabled)
        syncLaunchAtLoginRegistration()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard automaticallyChecksForUpdates != enabled else {
            return
        }

        automaticallyChecksForUpdates = enabled
        updateController.automaticallyChecksForUpdates = enabled
    }

    func setDebugModeEnabled(_ enabled: Bool) {
        guard debugModeEnabled != enabled else {
            return
        }

        debugModeEnabled = enabled
        diagnosticsStore.isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.debugModeEnabled)
    }

    func setStatusMenuUsesColor(_ enabled: Bool) {
        guard statusMenuUsesColor != enabled else {
            return
        }

        statusMenuUsesColor = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.statusMenuUsesColor)
    }

    func setStatusMenuShowsPercentages(_ enabled: Bool) {
        guard statusMenuShowsPercentages != enabled else {
            return
        }

        statusMenuShowsPercentages = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.statusMenuShowsPercentages)
    }

    func setStatusMenuLimitDisplay(_ display: StatusMenuLimitDisplay) {
        guard statusMenuLimitDisplay != display else {
            return
        }

        statusMenuLimitDisplay = display
        UserDefaults.standard.set(display.rawValue, forKey: Keys.statusMenuLimitDisplay)
    }

    func setShowUsageDetails(_ enabled: Bool) {
        guard showUsageDetails != enabled else {
            return
        }

        showUsageDetails = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.showUsageDetails)
    }

    func setOpenCodeGoEnabled(_ enabled: Bool) {
        guard openCodeGoEnabled != enabled else {
            return
        }

        openCodeGoEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.openCodeGoEnabled)

        if enabled {
            for account in accounts where account.service == .openCodeGo {
                refresh(account.id, trigger: .manual, force: true)
            }
        } else {
            for account in accounts where account.service == .openCodeGo {
                pendingForcedRefreshes[account.id] = nil
                sessionCoordinator.cancelRefresh(accountID: account.id)
            }
        }
    }

    private func setOpenCodeGoEnabledWithoutRefreshing(_ enabled: Bool) {
        openCodeGoEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.openCodeGoEnabled)
    }

    func checkForUpdates() {
        updateController.checkForUpdates()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func openDiagnosticsFolder() {
        NSWorkspace.shared.open(diagnosticsDirectoryURL)
    }

    func openGitHubDebugReportDraft() {
        let report = makeDebugReport()
        _ = diagnosticsStore.writeReport(report)
        var components = URLComponents(string: "https://github.com/MediaPublishing/token-monitor/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Token Monitor debug report"),
            URLQueryItem(name: "body", value: report)
        ]
        guard let url = components?.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openEmailDebugReportDraft() {
        let report = makeDebugReport()
        _ = diagnosticsStore.writeReport(report)
        let recipient = ["info", "@", "etraininghq", ".", "com"].joined()
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Token Monitor debug report"),
            URLQueryItem(name: "body", value: report)
        ]
        guard let url = components.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    var launchAtLoginStatusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled in macOS Login Items."
        case .requiresApproval:
            return "macOS requires approval in Login Items before Token Monitor can start automatically."
        case .notRegistered:
            return "Not registered yet. Keep Launch at login enabled after moving the app to Applications."
        case .notFound:
            return "macOS cannot find Token Monitor as a login item. Move the app to Applications, open it once, then toggle this setting again."
        @unknown default:
            return "macOS returned an unknown Login Items status."
        }
    }

    func stateDescription(for status: ServiceStatus) -> String {
        switch status.refreshState {
        case let .success(lastSuccess):
            return "Updated \(relativeDateText(from: lastSuccess))"
        case let .stale(lastSuccess, message):
            return "\(message) · last good snapshot \(relativeDateText(from: lastSuccess))"
        case let .authRequired(message):
            return message
        case let .failed(message):
            return message
        case let .refreshing(trigger):
            return "Refreshing from \(trigger.rawValue)…"
        case .idle:
            return "Waiting for first refresh"
        }
    }

    var lastRefreshText: String {
        let lastRefresh = enabledAccounts
            .compactMap { dashboardState.account($0.id)?.lastSuccessfulRefresh }
            .max()

        guard let lastRefresh else {
            return "No successful refresh yet"
        }

        return "Last updated \(relativeDateText(from: lastRefresh))"
    }

    var snapshotPathText: String {
        snapshotDirectoryURL.path
    }

    var diagnosticsPathText: String {
        diagnosticsDirectoryURL.path
    }

    var overallConnectionStatus: ServiceConnectionStatus {
        let states = enabledAccounts.compactMap { dashboardState.account($0.id)?.connectionStatus }
        if states.contains(.error) {
            return .error
        }
        if states.contains(.authRequired) {
            return .authRequired
        }
        if states.contains(.refreshing) {
            return .refreshing
        }
        if states.contains(.stale) {
            return .stale
        }
        return .healthy
    }

    func statusMenuScores(for service: ServiceKind) -> (session: Double?, total: Double?) {
        guard let snapshot = statusMenuStatus(for: service)?.snapshot else {
            return (nil, nil)
        }
        return (snapshot.statusMenuSessionScore, snapshot.statusMenuTotalScore)
    }

    func statusMenuStatus(for service: ServiceKind) -> ServiceStatus? {
        dashboardState.account(menuBarAccountID(for: service))
    }

    private func persistSnapshots() {
        let snapshots = Dictionary(
            uniqueKeysWithValues: dashboardState.services.filter(\.isPrimary).compactMap { status in
                status.snapshot.map { (status.service, $0) }
            }
        )

        do {
            try snapshotStore.saveSnapshots(snapshots)
        } catch {
            NSLog("Failed to persist legacy snapshots: \(error.localizedDescription)")
        }
        guard canPersistAccounts else { return }
        let updatedAccounts = accounts.map { account -> MonitoredAccount in
            var updated = account
            updated.snapshot = dashboardState.account(account.id)?.snapshot
            return updated
        }
        do {
            try accountStore.saveAccounts(updatedAccounts)
        } catch {
            NSLog("Failed to persist account snapshots: \(error.localizedDescription)")
        }
    }

    private func applyParseError(_ error: UsageParseError, for accountID: UUID) {
        switch error {
        case let .authRequired(message):
            DashboardReducer.reduce(
                &dashboardState,
                event: .account(accountID, .authRequired(message: message))
            )

        case let .unsupportedLayout(message):
            DashboardReducer.reduce(
                &dashboardState,
                event: .account(accountID, .refreshFailed(message: message))
            )
        }
    }

    private func shouldSkipAutomaticRefresh(for accountID: UUID, trigger: RefreshTrigger) -> Bool {
        dashboardState.account(accountID)?.shouldSkipAutomaticRefresh(trigger: trigger) ?? true
    }

    private var enabledAccounts: [MonitoredAccount] {
        accounts.filter { account in
            account.service != .openCodeGo || openCodeGoEnabled
        }
    }

    private func userVisibleMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty {
            return description
        }

        return error.localizedDescription
    }

    private func makeDebugReport() -> String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let debugModeText = debugModeEnabled ? "yes" : "no"

        var lines: [String] = [
            "# Token Monitor Debug Report",
            "",
            "Created: \(ISO8601DateFormatter().string(from: Date()))",
            "App version: \(shortVersion) (\(buildVersion))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Debug mode enabled: \(debugModeText)",
            "",
            "## Current status"
        ]

        for account in enabledAccounts {
            guard let status = dashboardState.account(account.id) else { continue }
            lines.append("- \(status.accountName): \(status.connectionStatus.rawValue) - \(stateDescription(for: status))")
        }

        lines.append("")
        lines.append("## Latest redacted debug records")

        let records = diagnosticsStore.latestRecords()
        if records.isEmpty {
            lines.append("No debug records found yet. Enable Debug mode, refresh a provider, then create the report again.")
        } else {
            for record in records {
                lines.append("")
                lines.append("### \(record.service.displayName)")
                lines.append("- Timestamp: \(ISO8601DateFormatter().string(from: record.timestamp))")
                lines.append("- Outcome: \(record.outcome.rawValue)")
                lines.append("- Page title: \(record.pageTitle)")
                lines.append("- URL: \(record.url)")
                if let message = record.message, !message.isEmpty {
                    lines.append("- Message: \(message)")
                }
                lines.append("")
                lines.append("Body preview:")
                lines.append("```")
                lines.append(record.bodyPreview)
                lines.append("```")
                lines.append("")
                lines.append("Segments:")
                lines.append("```")
                lines.append(record.segments.joined(separator: "\n---\n"))
                lines.append("```")
            }
        }

        lines.append("")
        lines.append("Note: This report is generated locally. Review it before submitting because usage values and page text can still be account-specific even after token/email redaction.")
        return lines.joined(separator: "\n")
    }

    private func relativeDateText(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func syncLaunchAtLoginRegistration() {
        do {
            if launchAtLoginEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update launch-at-login state: \(error.localizedDescription)")
        }
    }
}
