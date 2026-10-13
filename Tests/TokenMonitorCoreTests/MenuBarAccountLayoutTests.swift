import Testing
@testable import TokenMonitorCore

struct MenuBarAccountLayoutTests {
    @Test(arguments: 0...12)
    func compactGridHasNoMissingAccountsAndAtMostTwoColumns(count: Int) {
        let expected = [(0, 0), (1, 1), (1, 2), (1, 3), (2, 2), (2, 3), (2, 3)]
        let layout = MenuBarAccountLayout(accountCount: count)
        let visible = min(count, 6)
        #expect(layout.visibleCount == visible)
        #expect(layout.overflowCount == max(0, count - 6))
        #expect(layout.columnCount == expected[visible].0)
        #expect(layout.rowCount == expected[visible].1)
        var positions = Set<String>()
        for index in 0..<visible {
            let position = layout.position(at: index)
            #expect(position?.column == index / layout.rowCount)
            #expect(position?.row == index % layout.rowCount)
            positions.insert("\(position!.column):\(position!.row)")
        }
        #expect(positions.count == visible)
        #expect(layout.position(at: -1) == nil)
        #expect(layout.position(at: visible) == nil)
    }

    @Test func invalidCountProducesEmptyLayoutRatherThanNegativeOverflow() {
        let layout = MenuBarAccountLayout(accountCount: -1)
        #expect(layout == MenuBarAccountLayout(accountCount: 0))
        #expect(layout.position(at: 0) == nil)
    }
}
