import Foundation
import Testing
@testable import TokenMonitorCore

struct ClaudeUsageParserTests {
    @Test func parsesCurrentClaudeUsageLayout() throws {
        let bodyText = try FixtureLoader.text(named: "claude-usage-body")
        let extract = ServicePageExtract(
            service: .claude,
            pageTitle: "Usage",
            url: "https://claude.ai/settings/usage",
            bodyText: bodyText,
            segments: []
        )

        let snapshot = try ClaudeUsageParser().parse(extract: extract, now: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(snapshot.service == .claude)
        #expect(snapshot.metrics.count == 6)
        #expect(snapshot.metric(for: "current-session")?.valueText == "0% used")
        #expect(snapshot.metric(for: "current-session")?.progress == 0.0)
        #expect(snapshot.metric(for: "weekly-all-models")?.valueText == "100% used")
        #expect(snapshot.metric(for: "weekly-all-models")?.progress == 1.0)
        #expect(snapshot.metric(for: "weekly-all-models")?.subtitle == "Resets in 10 hr 14 min")
        #expect(snapshot.metric(for: "weekly-sonnet")?.valueText == "17% used")
        #expect(snapshot.metric(for: "weekly-sonnet")?.progress == 0.17)
        #expect(snapshot.metric(for: "extra-usage-spend")?.valueText == "$158.05 spent")
        #expect(snapshot.metric(for: "extra-usage-spend")?.progress == 0.79)
        #expect(snapshot.metric(for: "monthly-spend-limit")?.valueText == "$200")
        #expect(snapshot.metric(for: "current-balance")?.valueText == "$41.94")
    }

    @Test func throwsAuthRequiredForClaudeLoginPage() throws {
        let bodyText = try FixtureLoader.text(named: "claude-auth-body")
        let extract = ServicePageExtract(
            service: .claude,
            pageTitle: "Claude",
            url: "https://claude.ai/login",
            bodyText: bodyText,
            segments: []
        )

        #expect(throws: UsageParseError.authRequired("Claude login required")) {
            try ClaudeUsageParser().parse(extract: extract, now: .now)
        }
    }
}
