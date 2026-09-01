import Foundation
import Testing
@testable import TokenMonitorCore

struct OpenCodeGoUsageParserTests {
    @Test func parsesOpenCodeGoUsageDashboard() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/example/go",
            bodyText: """
            Go
            You are subscribed to OpenCode Go.
            Rolling Usage
            16%
            Resets in 4 hours 3 minutes
            Weekly Usage
            6%
            Resets in 3 days 1 hour
            Monthly Usage
            3%
            Resets in 30 days 23 hours
            """,
            segments: []
        )

        let snapshot = try OpenCodeGoUsageParser().parse(
            extract: extract,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(snapshot.service == .openCodeGo)
        #expect(snapshot.metric(for: "rolling-usage")?.valueText == "84% remaining")
        #expect(snapshot.metric(for: "rolling-usage")?.progress == 0.84)
        #expect(snapshot.metric(for: "rolling-usage")?.subtitle == "Resets in 4 hours 3 minutes")
        #expect(snapshot.metric(for: "weekly-usage")?.valueText == "94% remaining")
        #expect(snapshot.metric(for: "monthly-usage")?.valueText == "97% remaining")
        #expect(snapshot.capacityScore == 0.84)
        #expect(snapshot.statusMenuTotalScore == 0.94)
        #expect(snapshot.statusMenuSessionScore == 0.84)
    }

    @Test func rejectsOpenCodeGoLoginPage() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/go",
            bodyText: "Login to OpenCode",
            segments: []
        )

        #expect(throws: UsageParseError.authRequired("OpenCode Go login required")) {
            try OpenCodeGoUsageParser().parse(extract: extract, now: .now)
        }
    }

    @Test func acceptsPartialOpenCodeGoUsageWithoutInventingMissingBars() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/example/go",
            bodyText: """
            Rolling Usage
            16%
            Resets in 4 hours 3 minutes
            Weekly Usage
            6%
            Resets in 3 days 1 hour
            """,
            segments: []
        )

        let snapshot = try OpenCodeGoUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metrics.map(\.key) == ["rolling-usage", "weekly-usage"])
        #expect(snapshot.metric(for: "monthly-usage") == nil)
    }

    @Test func parsesGermanOpenCodeGoLabels() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/example/go",
            bodyText: """
            Du hast OpenCode Go abonniert.
            Fortlaufende Nutzung
            16 %
            Setzt zurück in 4 Stunden 3 Minuten
            Wöchentliche Nutzung
            6 %
            Setzt zurück in 3 Tagen 1 Stunde
            Monatliche Nutzung
            3 %
            Setzt zurück in 30 Tagen 23 Stunden
            """,
            segments: []
        )

        let snapshot = try OpenCodeGoUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metrics.map(\.key) == ["rolling-usage", "weekly-usage", "monthly-usage"])
        #expect(snapshot.metric(for: "rolling-usage")?.valueText == "84% remaining")
        #expect(snapshot.metric(for: "weekly-usage")?.subtitle == "Setzt zurück in 3 Tagen 1 Stunde")
    }

    @Test func doesNotBorrowPercentageFromTheNextUsageBlock() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/example/go",
            bodyText: """
            Rolling Usage
            Resets in 4 hours 3 minutes
            Weekly Usage
            6%
            Resets in 3 days 1 hour
            Monthly Usage
            3%
            Resets in 30 days 23 hours
            """,
            segments: []
        )

        let snapshot = try OpenCodeGoUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metrics.map(\.key) == ["weekly-usage", "monthly-usage"])
        #expect(snapshot.metric(for: "rolling-usage") == nil)
    }

    @Test func parsesCollapsedOpenCodeGoUsageTextWithoutReusingTheFirstPercentage() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/example/go",
            bodyText: "Rolling Usage 16% Resets in 4 hours 3 minutes Weekly Usage 6% Resets in 3 days 1 hour Monthly Usage 3% Resets in 30 days 23 hours",
            segments: []
        )

        let snapshot = try OpenCodeGoUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metric(for: "rolling-usage")?.valueText == "84% remaining")
        #expect(snapshot.metric(for: "weekly-usage")?.valueText == "94% remaining")
        #expect(snapshot.metric(for: "monthly-usage")?.valueText == "97% remaining")
    }

    @Test func parsesCurrentFiveHourUsageLayoutWithDecimalPercentages() throws {
        let extract = ServicePageExtract(
            service: .openCodeGo,
            pageTitle: "opencode",
            url: "https://opencode.ai/workspace/example/go",
            bodyText: """
            You are subscribed to OpenCode Go.
            5-hour Usage
            0%
            Resets in 2 hours 41 minutes
            Weekly Usage
            0%
            Resets in 5 days 10 hours
            Monthly Usage
            75.3%
            Resets in 5 days 7 hours
            """,
            segments: []
        )

        let snapshot = try OpenCodeGoUsageParser().parse(extract: extract, now: .now)

        #expect(snapshot.metrics.map(\.key) == ["rolling-usage", "weekly-usage", "monthly-usage"])
        #expect(snapshot.metric(for: "rolling-usage")?.title == "5 hour")
        #expect(snapshot.metric(for: "rolling-usage")?.valueText == "100% remaining")
        #expect(snapshot.metric(for: "monthly-usage")?.valueText == "25% remaining")
        #expect(snapshot.metric(for: "monthly-usage")?.progress == 0.247)
    }
}
