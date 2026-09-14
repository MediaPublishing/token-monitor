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
    }

    @Published private(set) var dashboardState: DashboardState
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
    private let diagnosticsStore: DiagnosticsStore
    private let sessionCoordinator: SessionCoordinator
    private let updateController: AppUpdateController
    private var refreshTasks: [ServiceKind: Task<Void, Never>] = [:]
    private var pendingForcedRefreshes: [ServiceKind: RefreshTrigger] = [:]
    private var backgroundRefreshTimer: Timer?

    init(
        snapshotStore: SnapshotPersisting = FileSnapshotStore(),
        updateController: AppUpdateController = .shared
    ) {
        self.snapshotStore = snapshotStore
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
        automaticallyChecksForUpdates = updateController.automaticallyChecksForUpdates
        let snapshots = (try? snapshotStore.loadSnapshots()) ?? [:]
        dashboardState = DashboardState.initial(lastSnapshots: snapshots)

        if let fileStore = snapshotStore as? FileSnapshotStore {
            snapshotDirectoryURL = fileStore.directoryURL
        } else {
            snapshotDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/TokenMonitor", isDirectory: true)
        }
        diagnosticsStore = DiagnosticsStore(baseDirectory: snapshotDirectoryURL, isEnabled: initialDebugModeEnabled)
        diagnosticsDirectoryURL = snapshotDirectoryURL.appendingPathComponent("Debug", isDirectory: true)
        sessionCoordinator = SessionCoordinator(diagnosticsStore: diagnosticsStore)
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
        for service in enabledServices {
            refresh(service, trigger: trigger, force: trigger == .manual)
        }
    }

    var dashboardServices: [ServiceStatus] {
        let order: [ServiceKind] = [.chatGPT, .claude, .openCodeGo]
        return order.compactMap { service in
            let status = dashboardState.service(service)
            if service == .openCodeGo && (!openCodeGoEnabled || status.snapshot == nil) {
                return nil
            }
            return status
        }
    }

    var providerSettingsServices: [ServiceStatus] {
        [.chatGPT, .claude].map { dashboardState.service($0) }
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
        guard service != .openCodeGo || openCodeGoEnabled else {
            return
        }

        if refreshTasks[service] != nil {
            if force {
                pendingForcedRefreshes[service] = trigger
            }
            return
        }

        if shouldSkipAutomaticRefresh(for: service, trigger: trigger) {
            return
        }

        DashboardReducer.reduce(&dashboardState, event: .service(service, .refreshStarted(trigger: trigger)))

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                Task { @MainActor in
                    self.refreshTasks[service] = nil
                    if let pendingTrigger = self.pendingForcedRefreshes.removeValue(forKey: service) {
                        self.refresh(service, trigger: pendingTrigger)
                    }
                }
            }

            do {
                let snapshot = try await sessionCoordinator.refresh(service: service)
                try Task.checkCancellation()
                await MainActor.run {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .service(service, .refreshSucceeded(snapshot))
                    )
                    self.persistSnapshots()
                    if service == .chatGPT {
                        self.resetReminders.update(snapshot.bankedResets)
                    }
                }
            } catch let parseError as UsageParseError {
                await MainActor.run {
                    self.applyParseError(parseError, for: service)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .service(service, .refreshFailed(message: self.userVisibleMessage(for: error)))
                    )
                }
            }
        }

        refreshTasks[service] = task
    }

    func openLogin(for service: ServiceKind, replacingExistingSession: Bool = false) {
        // Connecting an optional provider also opts it into refreshes and the menu.
        if service == .openCodeGo && !openCodeGoEnabled {
            setOpenCodeGoEnabledWithoutRefreshing(true)
        }
        sessionCoordinator.cancelRefresh(service: service)

        if replacingExistingSession {
            refreshTasks[service]?.cancel()
            if service == .chatGPT { resetReminders.disconnect() }
            DashboardReducer.reduce(
                &dashboardState,
                event: .service(service, .disconnected(message: "Connect account"))
            )
            persistSnapshots()
        }

        DashboardReducer.reduce(&dashboardState, event: .service(service, .refreshStarted(trigger: .login)))
        sessionCoordinator.showLoginWindow(
            for: service,
            replacingExistingSession: replacingExistingSession,
            onAuthenticated: { [weak self] in
                self?.refresh(service, trigger: .login, force: true)
            },
            onDismissed: { [weak self] in
                guard let self else {
                    return
                }
                if case .refreshing(trigger: .login) = self.dashboardState.service(service).refreshState {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .service(service, .refreshFailed(message: "Reconnect window closed before a successful refresh"))
                    )
                }
            }
        )
    }

    func switchAccount(for service: ServiceKind) {
        openLogin(for: service, replacingExistingSession: true)
    }

    func disconnect(_ service: ServiceKind) {
        if service == .chatGPT { resetReminders.disconnect() }
        pendingForcedRefreshes[service] = nil
        refreshTasks[service]?.cancel()
        sessionCoordinator.cancelRefresh(service: service)

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.sessionCoordinator.clearSession(for: service)
            if service == .openCodeGo {
                self.setOpenCodeGoEnabledWithoutRefreshing(false)
            }
            DashboardReducer.reduce(
                &self.dashboardState,
                event: .service(service, .disconnected(message: "Connect account"))
            )
            self.persistSnapshots()
        }
    }

    func openUsagePageInDefaultBrowser(for service: ServiceKind) {
        NSWorkspace.shared.open(service.usageURL)
    }

    func desiredPopoverHeight() -> CGFloat {
        switch popoverScreen {
        case .dashboard:
            return (showUsageDetails ? 650 : 540) + 32
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
            refresh(.openCodeGo, trigger: .manual, force: true)
        } else {
            pendingForcedRefreshes[.openCodeGo] = nil
            sessionCoordinator.cancelRefresh(service: .openCodeGo)
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
        let lastRefresh = enabledServices
            .compactMap { dashboardState.service($0).lastSuccessfulRefresh }
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
        let states = enabledServices.map { dashboardState.service($0).connectionStatus }
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
        guard let snapshot = dashboardState.service(service).snapshot else {
            return (nil, nil)
        }
        return (snapshot.statusMenuSessionScore, snapshot.statusMenuTotalScore)
    }

    private func persistSnapshots() {
        let snapshots = Dictionary(
            uniqueKeysWithValues: dashboardState.services.compactMap { status in
                status.snapshot.map { (status.service, $0) }
            }
        )

        do {
            try snapshotStore.saveSnapshots(snapshots)
        } catch {
            NSLog("Failed to persist snapshots: \(error.localizedDescription)")
        }
    }

    private func applyParseError(_ error: UsageParseError, for service: ServiceKind) {
        switch error {
        case let .authRequired(message):
            DashboardReducer.reduce(
                &dashboardState,
                event: .service(service, .authRequired(message: message))
            )

        case let .unsupportedLayout(message):
            DashboardReducer.reduce(
                &dashboardState,
                event: .service(service, .refreshFailed(message: message))
            )
        }
    }

    private func shouldSkipAutomaticRefresh(for service: ServiceKind, trigger: RefreshTrigger) -> Bool {
        dashboardState.service(service).shouldSkipAutomaticRefresh(trigger: trigger)
    }

    private var enabledServices: [ServiceKind] {
        ServiceKind.allCases.filter { service in
            service != .openCodeGo || openCodeGoEnabled
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

        for service in enabledServices {
            let status = dashboardState.service(service)
            lines.append("- \(status.service.displayName): \(status.connectionStatus.rawValue) - \(stateDescription(for: status))")
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
