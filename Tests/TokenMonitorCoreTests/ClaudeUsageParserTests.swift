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
        #expect(snapshot.metric(for: "current-session")?.valueText == "100% remaining")
        #expect(snapshot.metric(for: "current-session")?.progress == 1.0)
        #expect(snapshot.metric(for: "weekly-all-models")?.valueText == "0% remaining")
        #expect(snapshot.metric(for: "weekly-all-models")?.progress == 0.0)
        #expect(snapshot.metric(for: "weekly-all-models")?.subtitle == "Resets in 10 hr 14 min")
        #expect(snapshot.metric(for: "weekly-sonnet")?.valueText == "83% remaining")
        #expect(snapshot.metric(for: "weekly-sonnet")?.progress == 0.83)
        #expect(snapshot.metric(for: "extra-usage-spend")?.valueText == "$158.05 spent")
        #expect(snapshot.metric(for: "extra-usage-spend")?.progress == 0.79)
        #expect(snapshot.metric(for: "monthly-spend-limit")?.valueText == "$200")
        #expect(snapshot.metric(for: "current-balance")?.valueText == "$41.94")
    }

    @Test func parsesClaudeExtractWhenBodyTextIsCollapsedButSegmentsAreStructured() throws {
        let extract = ServicePageExtract(
            service: .claude,
            pageTitle: "Claude",
            url: "https://claude.ai/settings/usage",
            bodyText: "Plan usage limitsMax (20x)Current sessionStarts when a message is sent0% usedWeekly limitsAll modelsResets Fri 9:00 AM8% usedSonnet onlyResets Fri 9:00 AM6% usedExtra usage$200.23 spentResets May 1100% used$200Monthly spend limit$0.00Current balance",
            segments: [
                "Plan usage limits\nMax (20x)\nCurrent session\nStarts when a message is sent\n0% used\nWeekly limits\nLearn more about usage limits\nAll models\nResets Fri 9:00 AM\n8% used\nSonnet only\n\nResets Fri 9:00 AM\n6% used\nLast updated: less than a minute ago",
                "Extra usage\nTurn on extra usage to keep using Claude if you hit a limit. Learn more\n\n$200.23 spent\nResets May 1\n100% used\n$200\n\nMonthly spend limit\nAdjust limit\n$0.00\nCurrent balance·Auto-reload off\n\nBuy extra usage\nUp to 30% off"
            ]
        )

        let snapshot = try ClaudeUsageParser().parse(extract: extract, now: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(snapshot.metric(for: "current-session")?.valueText == "100% remaining")
        #expect(snapshot.metric(for: "weekly-all-models")?.valueText == "92% remaining")
        #expect(snapshot.metric(for: "weekly-all-models")?.subtitle == "Resets Fri 9:00 AM")
        #expect(snapshot.metric(for: "weekly-sonnet")?.valueText == "94% remaining")
        #expect(snapshot.metric(for: "weekly-sonnet")?.subtitle == "Resets Fri 9:00 AM")
        #expect(snapshot.metric(for: "extra-usage-spend")?.valueText == "$200.23 spent")
        #expect(snapshot.metric(for: "monthly-spend-limit")?.valueText == "$200")
        #expect(snapshot.metric(for: "current-balance")?.valueText == "$0.00")
    }

    @Test func rejectsClaudeExtractWhileBalanceIsStillLoading() throws {
        let extract = ServicePageExtract(
            service: .claude,
            pageTitle: "Claude",
            url: "https://claude.ai/settings/usage",
            bodyText: "Plan usage limitsMax (20x)Current sessionStarts when a message is sent0% usedWeekly limitsAll modelsResets Fri 8:59 AM8% usedSonnet onlyResets Fri 9:00 AM6% usedExtra usage$200.23 spentResets May 1100% used$200Monthly spend limitAdjust limitLoading...Current balance",
            segments: [
                "Current session\nStarts when a message is sent\n0% used",
                "All models\nResets Fri 8:59 AM\n8% used",
                "Sonnet only\n\nResets Fri 9:00 AM\n6% used",
                "Extra usage\n$200.23 spent\nResets May 1\n100% used\n$200\n\nMonthly spend limit\nAdjust limit\nLoading...\nCurrent balance·Auto-reload off"
            ]
        )

        #expect(throws: UsageParseError.unsupportedLayout("Claude usage layout could not be parsed")) {
            try ClaudeUsageParser().parse(extract: extract, now: .now)
        }
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
