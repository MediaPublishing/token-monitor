import AppKit
import Combine
import Foundation
import ServiceManagement
import TokenMonitorCore

enum PopoverScreen {
    case dashboard
    case settings
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private enum Keys {
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    @Published private(set) var dashboardState: DashboardState
    @Published private(set) var popoverScreen: PopoverScreen = .dashboard
    @Published private(set) var isPopoverVisible = false
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var automaticallyChecksForUpdates: Bool

    let snapshotDirectoryURL: URL
    let diagnosticsDirectoryURL: URL

    private let snapshotStore: SnapshotPersisting
    private let diagnosticsStore: DiagnosticsStore
    private let sessionCoordinator: SessionCoordinator
    private let updateController: AppUpdateController
    private var refreshTasks: [ServiceKind: Task<Void, Never>] = [:]
    private var backgroundRefreshTimer: Timer?

    private init(
        snapshotStore: SnapshotPersisting = FileSnapshotStore(),
        updateController: AppUpdateController = .shared
    ) {
        self.snapshotStore = snapshotStore
        self.updateController = updateController
        UserDefaults.standard.register(defaults: [Keys.launchAtLoginEnabled: true])
        launchAtLoginEnabled = UserDefaults.standard.bool(forKey: Keys.launchAtLoginEnabled)
        automaticallyChecksForUpdates = updateController.automaticallyChecksForUpdates
        let snapshots = (try? snapshotStore.loadSnapshots()) ?? [:]
        dashboardState = DashboardState.initial(lastSnapshots: snapshots)

        if let fileStore = snapshotStore as? FileSnapshotStore {
            snapshotDirectoryURL = fileStore.directoryURL
        } else {
            snapshotDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/TokenMonitor", isDirectory: true)
        }
        diagnosticsStore = DiagnosticsStore(baseDirectory: snapshotDirectoryURL)
        diagnosticsDirectoryURL = snapshotDirectoryURL.appendingPathComponent("Debug", isDirectory: true)
        sessionCoordinator = SessionCoordinator(diagnosticsStore: diagnosticsStore)
    }

    func start() {
        guard backgroundRefreshTimer == nil else {
            return
        }

        syncLaunchAtLoginRegistration()

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
        for service in ServiceKind.allCases {
            refresh(service, trigger: trigger, force: trigger == .manual)
        }
    }

    var isRefreshing: Bool {
        !refreshTasks.isEmpty
    }

    func refresh(_ service: ServiceKind, trigger: RefreshTrigger, force: Bool = false) {
        if !force, refreshTasks[service] != nil {
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
                }
            }

            do {
                let snapshot = try await sessionCoordinator.refresh(service: service)
                await MainActor.run {
                    DashboardReducer.reduce(
                        &self.dashboardState,
                        event: .service(service, .refreshSucceeded(snapshot))
                    )
                    self.persistSnapshots()
                }
            } catch let parseError as UsageParseError {
                await MainActor.run {
                    self.applyParseError(parseError, for: service)
                }
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

    func openLogin(for service: ServiceKind) {
        DashboardReducer.reduce(&dashboardState, event: .service(service, .refreshStarted(trigger: .login)))
        sessionCoordinator.showLoginWindow(
            for: service,
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

    func openUsagePageInDefaultBrowser(for service: ServiceKind) {
        NSWorkspace.shared.open(service.usageURL)
    }

    func desiredPopoverHeight() -> CGFloat {
        switch popoverScreen {
        case .dashboard:
            return 540
        case .settings:
            return 500
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

    func checkForUpdates() {
        updateController.checkForUpdates()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
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
        guard let lastRefresh = dashboardState.lastRefresh else {
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
        let states = dashboardState.services.map(\.connectionStatus)
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

    func capacityScore(for service: ServiceKind) -> Double? {
        guard let snapshot = dashboardState.service(service).snapshot else {
            return nil
        }
        return snapshot.capacityScore
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

    private func userVisibleMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty {
            return description
        }

        return error.localizedDescription
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
