import Foundation

public struct MenuBarAccountSelection: Equatable, Sendable {
    public private(set) var accountIDs: [String: [String]]

    public init(accountIDs: [String: [String]]? = nil, legacyAccountIDs: [String: String] = [:]) {
        self.accountIDs = accountIDs ?? legacyAccountIDs.mapValues { [$0] }
    }

    public func accounts(for service: ServiceKind, available: [MonitoredAccount]) -> [MonitoredAccount] {
        let candidates = available.filter { $0.service == service }
        var seen = Set<UUID>()
        let selected = (accountIDs[service.rawValue] ?? []).compactMap { raw -> MonitoredAccount? in
            guard let id = UUID(uuidString: raw), seen.insert(id).inserted else { return nil }
            return candidates.first { $0.id == id }
        }
        if !selected.isEmpty { return selected }
        return (candidates.first { $0.isPrimary } ?? candidates.first).map { [$0] } ?? []
    }

    @discardableResult
    public mutating func select(_ id: UUID, for service: ServiceKind, available: [MonitoredAccount]) -> Bool {
        guard available.contains(where: { $0.id == id && $0.service == service }) else { return false }
        var ids = accounts(for: service, available: available).map(\.id)
        if let index = ids.firstIndex(of: id) {
            ids.swapAt(0, index)
        } else if ids.isEmpty {
            ids = [id]
        } else {
            ids[0] = id
        }
        accountIDs[service.rawValue] = ids.map(\.uuidString)
        return true
    }

    @discardableResult
    public mutating func showAlongside(_ id: UUID, for service: ServiceKind, available: [MonitoredAccount]) -> Bool {
        guard available.contains(where: { $0.id == id && $0.service == service }) else { return false }
        var ids = accounts(for: service, available: available).map(\.id)
        guard !ids.contains(id) else { return false }
        ids.append(id)
        accountIDs[service.rawValue] = ids.map(\.uuidString)
        return true
    }

    @discardableResult
    public mutating func hide(_ id: UUID, for service: ServiceKind, available: [MonitoredAccount]) -> Bool {
        let ids = accounts(for: service, available: available).map(\.id)
        guard ids.count > 1, ids.contains(id) else { return false }
        accountIDs[service.rawValue] = ids.filter { $0 != id }.map(\.uuidString)
        return true
    }

    public mutating func reconcile(available: [MonitoredAccount]) {
        for service in ServiceKind.allCases {
            accountIDs[service.rawValue] = accounts(for: service, available: available).map { $0.id.uuidString }
        }
    }
}
