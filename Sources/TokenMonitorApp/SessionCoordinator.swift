import Foundation
import TokenMonitorCore
import WebKit

@MainActor
final class SessionCoordinator {
    private var controllers: [UUID: ServiceSessionController]

    init(diagnosticsStore: DiagnosticsStore, accounts: [MonitoredAccount]) {
        controllers = Dictionary(uniqueKeysWithValues: accounts.map { account in
            (account.id, Self.makeController(for: account, diagnosticsStore: diagnosticsStore))
        })
    }

    private static func makeController(for account: MonitoredAccount, diagnosticsStore: DiagnosticsStore) -> ServiceSessionController {
        let dataStore = account.isPrimary ? WKWebsiteDataStore.default() : WKWebsiteDataStore(forIdentifier: account.id)
        return ServiceSessionController(service: account.service, diagnosticsStore: diagnosticsStore,
                                        lastSnapshot: account.snapshot, dataStore: dataStore,
                                        isolatedAccount: !account.isPrimary)
    }

    func add(_ account: MonitoredAccount, diagnosticsStore: DiagnosticsStore) {
        controllers[account.id] = Self.makeController(for: account, diagnosticsStore: diagnosticsStore)
    }

    func remove(_ accountID: UUID) async {
        await controllers[accountID]?.clearSession()
        controllers[accountID] = nil
    }

    func refresh(accountID: UUID) async throws -> ServiceSnapshot {
        guard let controller = controllers[accountID] else {
            throw SessionControllerError.controllerMissing(accountID.uuidString)
        }

        return try await controller.refresh()
    }

    func cancelRefresh(service: ServiceKind) {
        cancelRefresh(accountID: service.dataStoreIdentifier)
    }

    func cancelRefresh(accountID: UUID) {
        controllers[accountID]?.cancelRefresh()
    }

    func showLoginWindow(
        for accountID: UUID,
        replacingExistingSession: Bool = false,
        onAuthenticated: @escaping @MainActor () -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        controllers[accountID]?.showLoginWindow(
            replacingExistingSession: replacingExistingSession,
            onAuthenticated: onAuthenticated,
            onDismissed: onDismissed
        )
    }

    func clearSession(for service: ServiceKind) async {
        await controllers[service.dataStoreIdentifier]?.clearSession()
    }

    func clearSession(for accountID: UUID) async {
        await controllers[accountID]?.clearSession()
    }
}
