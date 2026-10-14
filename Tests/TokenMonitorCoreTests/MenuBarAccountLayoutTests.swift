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

    @Test(arguments: 0...12)
    func providerLayoutGroupsAccountsAndKeepsEveryProviderVisible(count: Int) {
        let providers: [ServiceKind] = [.chatGPT, .claude, .openCodeGo]
        let services = (0..<count).map { providers[$0 % providers.count] }
        let layout = MenuBarAccountLayout(accountServices: services, arrangement: .byProvider)
        #expect(layout.visibleCount <= 6)
        #expect(layout.columnCount == min(count, 3))
        #expect(layout.rowCount <= 3)
        #expect(layout.overflowCount == count - layout.visibleCount)
        for provider in providers where services.contains(provider) {
            let indexes = services.indices.filter { services[$0] == provider }
            #expect(layout.position(at: indexes[0]) != nil)
            let positions = indexes.compactMap { layout.position(at: $0) }
            #expect(Set(positions.map(\.column)).count == 1)
            #expect(positions.map(\.row) == Array(0..<positions.count))
        }
        #expect(layout.position(at: -1) == nil)
        #expect(layout.position(at: count) == nil)
        #expect(MenuBarAccountLayout(accountServices: services) == MenuBarAccountLayout(accountCount: count))
    }

    @Test func multipleClaudeAccountsShareOneColumnWithoutEmptyProviderColumns() {
        let layout = MenuBarAccountLayout(accountServices: [.chatGPT, .claude, .claude], arrangement: .byProvider)
        #expect(layout.columnCount == 2 && layout.rowCount == 2)
        #expect(layout.position(at: 0) == .init(column: 0, row: 0))
        #expect(layout.position(at: 1) == .init(column: 1, row: 0))
        #expect(layout.position(at: 2) == .init(column: 1, row: 1))
    }

    @Test(arguments: 0...12)
    func accountColumnsKeepEverySelectedAccountInItsOwnColumn(count: Int) {
        let services = (0..<count).map { $0 == 0 ? ServiceKind.chatGPT : .claude }
        let arrangement = MenuBarAccountArrangement(persistedValue: "byAccount")
        let layout = MenuBarAccountLayout(accountServices: services, arrangement: arrangement)
        let visible = min(count, 6)
        #expect(layout.visibleCount == visible)
        #expect(layout.overflowCount == max(0, count - visible))
        #expect(layout.columnCount == visible)
        #expect(layout.rowCount == (visible == 0 ? 0 : 1))
        for index in 0..<visible {
            #expect(layout.position(at: index) == .init(column: index, row: 0))
        }
        #expect(layout.position(at: -1) == nil)
        #expect(layout.position(at: visible) == nil)
    }

    @Test func providerOverflowDoesNotHideTheNextProvider() {
        let services = Array(repeating: ServiceKind.chatGPT, count: 5)
            + Array(repeating: ServiceKind.claude, count: 5) + [.openCodeGo]
        let layout = MenuBarAccountLayout(accountServices: services, arrangement: .byProvider)
        #expect(layout.visibleCount == 6 && layout.overflowCount == 5)
        #expect(layout.columnCount == 3 && layout.rowCount == 3)
        #expect(layout.position(at: 3) == nil)
        #expect(layout.position(at: 5) == .init(column: 1, row: 0))
        #expect(layout.position(at: 10) == .init(column: 2, row: 0))
        let single = MenuBarAccountLayout(accountServices: Array(repeating: .claude, count: 8), arrangement: .byProvider)
        #expect(single.columnCount == 1 && single.rowCount == 3)
        #expect(single.visibleCount == 3 && single.overflowCount == 5)
    }

    @Test func oldOrInvalidPreferenceKeepsCompactDefault() {
        #expect(MenuBarAccountArrangement(persistedValue: nil) == .compact)
        #expect(MenuBarAccountArrangement(persistedValue: "") == .compact)
        #expect(MenuBarAccountArrangement(persistedValue: "unknown") == .compact)
        #expect(MenuBarAccountArrangement(persistedValue: "byProvider") == .byProvider)
        #expect(MenuBarAccountArrangement(persistedValue: "byAccount") == .byAccount)
        #expect(MenuBarAccountLayout(accountServices: [], arrangement: .byProvider) == MenuBarAccountLayout(accountCount: 0))
    }
}
