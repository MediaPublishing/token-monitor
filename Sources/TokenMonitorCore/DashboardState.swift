import Foundation

public struct DashboardState: Equatable, Sendable {
    public var services: [ServiceStatus]

    public init(services: [ServiceStatus]) {
        self.services = services.sorted { lhs, rhs in
            if lhs.service.displayOrder != rhs.service.displayOrder {
                return lhs.service.displayOrder < rhs.service.displayOrder
            }
            if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
            return lhs.accountName.localizedStandardCompare(rhs.accountName) == .orderedAscending
        }
    }

    public static func initial(lastSnapshots: [ServiceKind: ServiceSnapshot]) -> DashboardState {
        initial(accounts: AccountMigration.restoring([], legacySnapshots: lastSnapshots))
    }

    public static func initial(accounts: [MonitoredAccount]) -> DashboardState {
        DashboardState(services: accounts.map { account in
            let snapshot = account.snapshot
            return ServiceStatus(
                service: account.service,
                snapshot: snapshot,
                refreshState: snapshot.map {
                    .stale(lastSuccess: $0.capturedAt, message: "Last successful snapshot")
                } ?? .authRequired(message: "Connect account"),
                accountID: account.id,
                accountName: account.name,
                isPrimary: account.isPrimary
            )
        })
    }

    public func service(_ kind: ServiceKind) -> ServiceStatus {
        services.first(where: { $0.service == kind && $0.isPrimary })!
    }

    public func account(_ id: UUID) -> ServiceStatus? {
        services.first(where: { $0.accountID == id })
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
    case disconnected(message: String)
}

public enum DashboardEvent: Equatable, Sendable {
    case service(ServiceKind, ServiceRefreshEvent)
    case account(UUID, ServiceRefreshEvent)
}

public enum DashboardReducer {
    public static func reduce(_ state: inout DashboardState, event: DashboardEvent, now _: Date = .now) {
        let accountID: UUID
        let refreshEvent: ServiceRefreshEvent
        switch event {
        case let .service(service, event):
            accountID = service.dataStoreIdentifier
            refreshEvent = event
        case let .account(id, event):
            accountID = id
            refreshEvent = event
        }
        guard let index = state.services.firstIndex(where: { $0.accountID == accountID }) else {
            return
        }

        switch refreshEvent {
        case let .refreshStarted(trigger):
            state.services[index].refreshState = .refreshing(trigger: trigger)

        case let .refreshSucceeded(snapshot):
            var updated = snapshot
            if snapshot.service == .chatGPT, updated.bankedResets == nil {
                updated.bankedResets = state.services[index].snapshot?.bankedResets
            }
            state.services[index].snapshot = updated
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

        case let .disconnected(message):
            state.services[index].snapshot = nil
            state.services[index].refreshState = .authRequired(message: message)
        }
    }
}
