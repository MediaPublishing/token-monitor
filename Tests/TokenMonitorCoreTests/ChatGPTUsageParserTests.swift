import Foundation
import Testing
@testable import TokenMonitorCore

struct ChatGPTUsageParserTests {
    @Test func parsesCurrentChatGPTUsageLayout() throws {
        let bodyText = try FixtureLoader.text(named: "chatgpt-usage-body")
        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Usage dashboard",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            bodyText: bodyText,
            segments: []
        )

        let snapshot = try ChatGPTUsageParser().parse(extract: extract, now: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(snapshot.service == .chatGPT)
        #expect(snapshot.metrics.count == 5)
        #expect(snapshot.metric(for: "five-hour-limit")?.valueText == "99% remaining")
        #expect(snapshot.metric(for: "five-hour-limit")?.progress == 0.99)
        #expect(snapshot.metric(for: "five-hour-limit")?.subtitle == "Resets 5:55 PM")
        #expect(snapshot.metric(for: "weekly-limit")?.valueText == "100% remaining")
        #expect(snapshot.metric(for: "weekly-limit")?.progress == 1.0)
        #expect(snapshot.metric(for: "spark-five-hour-limit")?.valueText == "100% remaining")
        #expect(snapshot.metric(for: "spark-weekly-limit")?.valueText == "100% remaining")
        #expect(snapshot.metric(for: "credits-remaining")?.valueText == "0")
    }

    @Test func throwsAuthRequiredForChatGPTLoginPage() throws {
        let bodyText = try FixtureLoader.text(named: "chatgpt-auth-body")
        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Log in",
            url: "https://chatgpt.com/auth/login",
            bodyText: bodyText,
            segments: []
        )

        #expect(throws: UsageParseError.authRequired("ChatGPT login required")) {
            try ChatGPTUsageParser().parse(extract: extract, now: .now)
        }
    }

    @Test func parsesVariantChatGPTUsageLayoutWithNewerModelTitles() throws {
        let bodyText = try FixtureLoader.text(named: "chatgpt-usage-body-variant")
        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Usage dashboard",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            bodyText: bodyText,
            segments: []
        )

        let snapshot = try ChatGPTUsageParser().parse(extract: extract, now: Date(timeIntervalSince1970: 1_700_000_123))

        #expect(snapshot.metric(for: "five-hour-limit")?.valueText == "82% remaining")
        #expect(snapshot.metric(for: "weekly-limit")?.valueText == "64% remaining")
        #expect(snapshot.metric(for: "spark-five-hour-limit")?.title == "GPT-5.4-Codex 5-hour usage limit")
        #expect(snapshot.metric(for: "spark-five-hour-limit")?.valueText == "91% remaining")
        #expect(snapshot.metric(for: "spark-weekly-limit")?.title == "GPT-5.4-Codex weekly usage limit")
        #expect(snapshot.metric(for: "spark-weekly-limit")?.valueText == "88% remaining")
        #expect(snapshot.metric(for: "credits-remaining")?.valueText == "12.50")
    }

    @Test func keepsWeeklyResetFromRicherDuplicateUsageSegment() throws {
        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Codex",
            url: "https://chatgpt.com/codex/cloud/settings/analytics#usage",
            bodyText: "",
            segments: [
                """
                Weekly usage limit
                87%
                remaining
                Resets Apr 23, 2026 12:55 PM
                """,
                """
                Weekly usage limit
                87%
                remaining
                """,
                """
                5 hour usage limit
                97%
                remaining
                Resets 12:30 PM
                """,
                """
                GPT-5.3-Codex-Spark Weekly usage limit
                100%
                remaining
                """
            ]
        )

        let snapshot = try ChatGPTUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metric(for: "weekly-limit")?.valueText == "87% remaining")
        #expect(snapshot.metric(for: "weekly-limit")?.subtitle == "Resets Apr 23, 2026 12:55 PM")
    }

    @Test func parsesPartialChatGPTUsageLayoutWithoutFailingWholeSnapshot() throws {
        let bodyText = """
        Usage dashboard
        Balance

        5 hour usage limit
        98%
        remaining
        Resets Apr 16, 2026 12:55 PM

        GPT-5.4-Codex Weekly usage limit
        100%
        remaining
        """

        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Usage dashboard",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            bodyText: bodyText,
            segments: []
        )

        let snapshot = try ChatGPTUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metrics.count == 2)
        #expect(snapshot.metric(for: "five-hour-limit")?.valueText == "98% remaining")
        #expect(snapshot.metric(for: "five-hour-limit")?.subtitle == "Resets Apr 16, 2026 12:55 PM")
        #expect(snapshot.metric(for: "spark-weekly-limit")?.valueText == "100% remaining")
    }

    @Test func rejectsIncompleteSegmentCardsWithoutCrashing() throws {
        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Codex",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            bodyText: """
            Usage dashboard
            5 hour usage limit
            97% remaining
            Resets 10:57 PM
            """,
            segments: [
                "Weekly usage limit",
                "Credits remaining"
            ]
        )

        #expect(throws: UsageParseError.unsupportedLayout("ChatGPT usage layout could not be parsed")) {
            try ChatGPTUsageParser().parse(extract: extract, now: .now)
        }
    }

    @Test func rejectsLoadingStateThatOnlyContainsCredits() throws {
        let extract = ServicePageExtract(
            service: .chatGPT,
            pageTitle: "Codex",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            bodyText: """
            Usage dashboard
            Loading usage data
            Credits remaining
            0
            """,
            segments: [
                "Credits remaining\n0"
            ]
        )

        #expect(throws: UsageParseError.unsupportedLayout("ChatGPT usage layout could not be parsed")) {
            try ChatGPTUsageParser().parse(extract: extract, now: .now)
        }
    }
}
