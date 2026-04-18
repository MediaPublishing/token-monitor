import Foundation

public struct DashboardState: Equatable, Sendable {
    public var services: [ServiceStatus]

    public init(services: [ServiceStatus]) {
        self.services = services.sorted { lhs, rhs in
            lhs.service.displayOrder < rhs.service.displayOrder
        }
    }

    public static func initial(lastSnapshots: [ServiceKind: ServiceSnapshot]) -> DashboardState {
        DashboardState(
            services: ServiceKind.allCases.map { service in
                if let snapshot = lastSnapshots[service] {
                    return ServiceStatus(
                        service: service,
                        snapshot: snapshot,
                        refreshState: .stale(lastSuccess: snapshot.capturedAt, message: "Last successful snapshot")
                    )
                }

                return ServiceStatus(
                    service: service,
                    snapshot: nil,
                    refreshState: .authRequired(message: "Connect account")
                )
            }
        )
    }

    public func service(_ kind: ServiceKind) -> ServiceStatus {
        services.first(where: { $0.service == kind })!
    }

    public var lastRefresh: Date? {
        services.compactMap(\.lastSuccessfulRefresh).max()
    }
}

public enum ServiceRefreshEvent: Equatable, Sendable {
    case refreshStarted(trigger: RefreshTrigger)
    case refreshSucceeded(ServiceSnapshot)
    case refreshFailed(message: String)
    case authRequired(message: String)
}

public enum DashboardEvent: Equatable, Sendable {
    case service(ServiceKind, ServiceRefreshEvent)
}

public enum DashboardReducer {
    public static func reduce(_ state: inout DashboardState, event: DashboardEvent, now _: Date = .now) {
        switch event {
        case let .service(service, refreshEvent):
            guard let index = state.services.firstIndex(where: { $0.service == service }) else {
                return
            }

            switch refreshEvent {
            case let .refreshStarted(trigger):
                state.services[index].refreshState = .refreshing(trigger: trigger)

            case let .refreshSucceeded(snapshot):
                state.services[index].snapshot = snapshot
                state.services[index].refreshState = .success(lastSuccess: snapshot.capturedAt)

            case let .refreshFailed(message):
                if let snapshot = state.services[index].snapshot {
                    state.services[index].refreshState = .stale(lastSuccess: snapshot.capturedAt, message: message)
                } else {
                    state.services[index].refreshState = .failed(message: message)
                }

            case let .authRequired(message):
                if let snapshot = state.services[index].snapshot {
                    state.services[index].refreshState = .stale(lastSuccess: snapshot.capturedAt, message: message)
                } else {
                    state.services[index].refreshState = .authRequired(message: message)
                }
            }
        }
    }
}
