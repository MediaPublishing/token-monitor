import Foundation
import TokenMonitorCore

@MainActor
final class SessionCoordinator {
    private let controllers: [ServiceKind: ServiceSessionController]

    init(diagnosticsStore: DiagnosticsStore) {
        controllers = Dictionary(uniqueKeysWithValues: ServiceKind.allCases.map { service in
            (service, ServiceSessionController(service: service, diagnosticsStore: diagnosticsStore))
        })
    }

    func refresh(service: ServiceKind) async throws -> ServiceSnapshot {
        guard let controller = controllers[service] else {
            throw SessionControllerError.controllerMissing(service.displayName)
        }

        return try await controller.refresh()
    }

    func showLoginWindow(
        for service: ServiceKind,
        onAuthenticated: @escaping @MainActor () -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        controllers[service]?.showLoginWindow(
            onAuthenticated: onAuthenticated,
            onDismissed: onDismissed
        )
    }
}
