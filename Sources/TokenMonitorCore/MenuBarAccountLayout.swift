public enum MenuBarAccountArrangement: String, CaseIterable, Identifiable, Sendable {
    case compact
    case byProvider

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .compact: "Compact"
        case .byProvider: "By provider"
        }
    }

    public init(persistedValue: String?) {
        self = Self(rawValue: persistedValue ?? "") ?? .compact
    }
}

public struct MenuBarAccountLayout: Equatable, Sendable {
    public static let maximumVisibleAccounts = 6
    public static let maximumRowsPerProvider = 3

    public let visibleCount: Int
    public let overflowCount: Int
    public let columnCount: Int
    public let rowCount: Int
    private let positions: [Int: Position]

    public init(accountCount: Int) {
        let count = max(0, accountCount)
        visibleCount = min(count, Self.maximumVisibleAccounts)
        overflowCount = max(0, count - visibleCount)
        columnCount = visibleCount == 0 ? 0 : (visibleCount <= 3 ? 1 : 2)
        rowCount = columnCount == 0 ? 0 : (visibleCount + columnCount - 1) / columnCount
        let rows = rowCount
        positions = Dictionary(uniqueKeysWithValues: (0..<visibleCount).map {
            ($0, Position(column: $0 / rows, row: $0 % rows))
        })
    }

    public init(accountServices: [ServiceKind], arrangement: MenuBarAccountArrangement = .compact) {
        guard arrangement == .byProvider else {
            self.init(accountCount: accountServices.count)
            return
        }
        var providers: [ServiceKind] = []
        for service in accountServices where !providers.contains(service) { providers.append(service) }
        let groups = Dictionary(grouping: accountServices.indices) { accountServices[$0] }
        // Reserve the first account of every provider before filling additional rows.
        var counts = Dictionary(uniqueKeysWithValues: providers.map { ($0, 1) })
        var remaining = Self.maximumVisibleAccounts - providers.count
        for service in providers {
            let extra = min((groups[service]?.count ?? 1) - 1, Self.maximumRowsPerProvider - 1, remaining)
            counts[service, default: 1] += extra
            remaining -= extra
        }
        var result: [Int: Position] = [:]
        for (column, service) in providers.enumerated() {
            for (row, index) in (groups[service] ?? []).prefix(counts[service] ?? 1).enumerated() {
                result[index] = Position(column: column, row: row)
            }
        }
        self.init(accountCount: accountServices.count, columnCount: providers.count,
                  rowCount: counts.values.max() ?? 0, positions: result)
    }

    private init(accountCount: Int, columnCount: Int, rowCount: Int, positions: [Int: Position]) {
        self.positions = positions
        visibleCount = positions.count
        overflowCount = accountCount - visibleCount
        self.columnCount = columnCount
        self.rowCount = rowCount
    }

    public func position(at index: Int) -> Position? {
        positions[index]
    }

    public struct Position: Equatable, Sendable {
        public let column: Int
        public let row: Int
    }
}
