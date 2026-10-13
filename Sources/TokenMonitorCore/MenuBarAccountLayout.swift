public struct MenuBarAccountLayout: Equatable, Sendable {
    public static let maximumVisibleAccounts = 6

    public let visibleCount: Int
    public let overflowCount: Int
    public let columnCount: Int
    public let rowCount: Int

    public init(accountCount: Int) {
        let count = max(0, accountCount)
        visibleCount = min(count, Self.maximumVisibleAccounts)
        overflowCount = max(0, count - visibleCount)
        columnCount = visibleCount == 0 ? 0 : (visibleCount <= 3 ? 1 : 2)
        rowCount = columnCount == 0 ? 0 : (visibleCount + columnCount - 1) / columnCount
    }

    public func position(at index: Int) -> Position? {
        guard (0..<visibleCount).contains(index) else { return nil }
        return Position(column: index / rowCount, row: index % rowCount)
    }

    public struct Position: Equatable, Sendable {
        public let column: Int
        public let row: Int
    }
}
