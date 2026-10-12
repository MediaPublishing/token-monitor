import Testing
@testable import TokenMonitorCore

struct PopoverSizingTests {
    @Test func shortContentDoesNotReserveSpaceForAbsentAccounts() {
        let one = PopoverLayout(header: 32, content: 110, footer: 0, spacing: 30, maximumHeight: 760)
        let two = PopoverLayout(header: 32, content: 250, footer: 0, spacing: 30, maximumHeight: 760)
        #expect(one.height == 172)
        #expect(two.height == 312)
        #expect(!one.scrolls && !two.scrolls)
    }

    @Test func expandedDetailsAndFooterContributeTheirActualHeight() {
        let closed = PopoverLayout(header: 32, content: 250, footer: 16, spacing: 40, maximumHeight: 760)
        let expanded = PopoverLayout(header: 32, content: 310, footer: 58, spacing: 40, maximumHeight: 760)
        #expect(expanded.height - closed.height == 102)
        #expect(expanded.contentHeight == 310)
    }

    @Test func screenBudgetBoundsOnlyTheScrollableBody() {
        let value = PopoverLayout(header: 32, content: 950, footer: 16, spacing: 40, maximumHeight: 480)
        #expect(value.height == 480)
        #expect(value.contentHeight == 392)
        #expect(value.scrolls)
    }

    @Test func identicalRefreshGeometryAndScreenChangesStayStable() {
        let first = PopoverLayout(header: 32, content: 250, footer: 0, spacing: 30, maximumHeight: 760)
        let refreshed = PopoverLayout(header: 32, content: 250, footer: 0, spacing: 30, maximumHeight: 760)
        #expect(first == refreshed)
        #expect(PopoverLayout(header: 32, content: 250, footer: 0, spacing: 30, maximumHeight: 200).height == 200)
    }
}
