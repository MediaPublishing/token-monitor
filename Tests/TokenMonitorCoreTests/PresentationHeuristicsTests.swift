import Foundation
import Testing
@testable import TokenMonitorCore

struct PresentationHeuristicsTests {
    @Test func dashboardOrdersClaudeChatGPTBeforeOptionalOpenCodeGo() {
        let chatGPTSnapshot = ServiceSnapshot(
            service: .chatGPT,
            capturedAt: .now,
            pageTitle: "Codex",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            metrics: []
        )
        let claudeSnapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: .now,
            pageTitle: "Claude",
            url: "https://claude.ai/settings/usage",
            metrics: []
        )

        let state = DashboardState.initial(lastSnapshots: [
            .chatGPT: chatGPTSnapshot,
            .claude: claudeSnapshot
        ])

        #expect(state.services.map(\.service) == [.claude, .chatGPT, .openCodeGo])
    }

    @Test func capacityScoreUsesMostConstrainedMetricForClaude() {
        let snapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: .now,
            pageTitle: "Claude",
            url: "https://claude.ai/settings/usage",
            metrics: [
                UsageMetric(key: "current-session", title: "Current session", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress),
                UsageMetric(key: "weekly-all-models", title: "All models", valueText: "0% remaining", subtitle: nil, progress: 0, style: .progress),
                UsageMetric(key: "weekly-sonnet", title: "Sonnet only", valueText: "83% remaining", subtitle: nil, progress: 0.83, style: .progress)
            ]
        )

        #expect(snapshot.capacityScore == 0)
    }

    @Test func capacityScoreKeepsHighChatGPTRemainingValue() {
        let snapshot = ServiceSnapshot(
            service: .chatGPT,
            capturedAt: .now,
            pageTitle: "Codex",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            metrics: [
                UsageMetric(key: "five-hour-limit", title: "5 hour usage limit", valueText: "96% remaining", subtitle: nil, progress: 0.96, style: .progress),
                UsageMetric(key: "weekly-limit", title: "Weekly usage limit", valueText: "98% remaining", subtitle: nil, progress: 0.98, style: .progress),
                UsageMetric(key: "spark-five-hour-limit", title: "GPT-5.3-Codex-Spark 5 hour usage limit", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress),
                UsageMetric(key: "spark-weekly-limit", title: "GPT-5.3-Codex-Spark Weekly usage limit", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress)
            ]
        )

        #expect(snapshot.capacityScore == 0.96)
    }

    @Test func statusMenuSeparatesTotalAndSessionScoresForClaude() {
        let snapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: .now,
            pageTitle: "Claude",
            url: "https://claude.ai/settings/usage",
            metrics: [
                UsageMetric(key: "current-session", title: "Current session", valueText: "94% remaining", subtitle: nil, progress: 0.94, style: .progress),
                UsageMetric(key: "weekly-all-models", title: "All models", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress),
                UsageMetric(key: "weekly-sonnet", title: "Sonnet only", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress)
            ]
        )

        #expect(snapshot.statusMenuTotalScore == 1)
        #expect(snapshot.statusMenuSessionScore == 0.94)
    }

    @Test(arguments: [(1.0, 0.07), (0.66, 0.47)])
    func claudeMenuBarUsesEachAccountsSessionAndAllModels(session: Double, total: Double) {
        let snapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: .now,
            pageTitle: "Claude",
            url: ServiceKind.claude.usageURL.absoluteString,
            metrics: [
                UsageMetric(key: "current-session", title: "Session", valueText: "\(Int(session * 100))% remaining", subtitle: nil, progress: session, style: .progress),
                UsageMetric(key: "weekly-all-models", title: "All models", valueText: "\(Int(total * 100))% remaining", subtitle: nil, progress: total, style: .progress),
                UsageMetric(key: "weekly-sonnet", title: "Fable", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress)
            ]
        )

        #expect(snapshot.statusMenuSessionScore == session)
        #expect(snapshot.statusMenuTotalScore == total)
    }

    @Test func statusMenuSeparatesWeeklyAndFiveHourScoresForChatGPT() {
        let snapshot = ServiceSnapshot(
            service: .chatGPT,
            capturedAt: .now,
            pageTitle: "Codex",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            metrics: [
                UsageMetric(key: "five-hour-limit", title: "5 hour usage limit", valueText: "55% remaining", subtitle: nil, progress: 0.55, style: .progress),
                UsageMetric(key: "weekly-limit", title: "Weekly usage limit", valueText: "67% remaining", subtitle: nil, progress: 0.67, style: .progress),
                UsageMetric(key: "spark-five-hour-limit", title: "GPT-5.3-Codex-Spark 5 hour usage limit", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress),
                UsageMetric(key: "spark-weekly-limit", title: "GPT-5.3-Codex-Spark Weekly usage limit", valueText: "100% remaining", subtitle: nil, progress: 1, style: .progress)
            ]
        )

        #expect(snapshot.statusMenuTotalScore == 0.67)
        #expect(snapshot.statusMenuSessionScore == 0.55)
    }

    @Test func statusMenuUsesWeeklyAndRollingScoresForOpenCodeGo() {
        let snapshot = ServiceSnapshot(
            service: .openCodeGo,
            capturedAt: .now,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/example/go",
            metrics: [
                UsageMetric(key: "rolling-usage", title: "Rolling Usage", valueText: "84% remaining", subtitle: nil, progress: 0.84, style: .progress),
                UsageMetric(key: "weekly-usage", title: "Weekly Usage", valueText: "94% remaining", subtitle: nil, progress: 0.94, style: .progress),
                UsageMetric(key: "monthly-usage", title: "Monthly Usage", valueText: "97% remaining", subtitle: nil, progress: 0.97, style: .progress)
            ]
        )

        #expect(snapshot.capacityScore == 0.84)
        #expect(snapshot.statusMenuTotalScore == 0.94)
        #expect(snapshot.statusMenuSessionScore == 0.84)
    }

    @Test func displaySubtitleUsesCompactTwentyFourHourResetTimes() {
        let shortReset = UsageMetric(
            key: "five-hour-limit",
            title: "5 hour usage limit",
            valueText: "100% remaining",
            subtitle: "Resets 5:55 PM",
            progress: 1,
            style: .progress
        )
        let longReset = UsageMetric(
            key: "weekly-limit",
            title: "Weekly usage limit",
            valueText: "52% remaining",
            subtitle: "Resets May 11, 2026 6:30 PM",
            progress: 0.52,
            style: .progress
        )
        let noonReset = UsageMetric(
            key: "weekly-all-models",
            title: "All models",
            valueText: "95% remaining",
            subtitle: "Resets Fri 12:00 PM",
            progress: 0.95,
            style: .progress
        )

        #expect(shortReset.displaySubtitle == "Reset: 17:55")
        #expect(longReset.displaySubtitle == "Reset: May 11 18:30")
        #expect(noonReset.displaySubtitle == "Reset: Fri 12:00")
    }

    @Test(arguments: [
        ("Wird um 23:10 zurückgesetzt", "Reset: 23:10"),
        ("Zurücksetzung am Montag, 12:00", "Reset: Mo 12:00"),
        ("Zurückgesetzt am Freitag um 19:30", "Reset: Fr 19:30"),
        ("Wird in 5 Std. 0 Min. zurückgesetzt", "Reset: in 5Std 0min"),
        ("Zurücksetzung in 7 Tagen 2 Stunden", "Reset: in 7T 2Std"),
        ("Bis zum Zurücksetzen: 5 Std. 10 Min.", "Reset: 5Std 10min"),
        ("Resets in 5 days 11 hours", "Reset: in 5d 11h"),
        ("Resets in 1 hour 37 minutes", "Reset: in 1h 37min"),
        ("Resets Friday at 12 PM", "Reset: Fri 12:00"),
        ("Resets on Wednesday at 12:01 AM", "Reset: Wed 00:01"),
        ("Resets September 29, 2026 8:50 AM", "Reset: Sep 29 08:50"),
        ("Zurücksetzung am 22. Oktober 2026 um 16:28", "Reset: 22. Okt 16:28"),
        ("Reset: Fr 12:00", "Reset: Fr 12:00"),
        ("Starts with your first message", "Starts with your first message"),
        ("Paused until the weekly reset", "Paused until the weekly reset"),
        ("Reset time unavailable", "Reset: time unavailable")
    ])
    func resetPresentationKeepsDatesAndPreservesRawProviderText(input: String, expected: String) {
        let metric = UsageMetric(key: "current-session", title: "Session", valueText: "86% remaining",
                                 subtitle: input, progress: 0.86, style: .progress)
        #expect(metric.displaySubtitle == expected)
        #expect(metric.subtitle == input)
    }

    @Test func missingResetAndSeparateModelLimitsStayHonest() {
        let missing = UsageMetric(key: "weekly-limit", title: "Weekly", valueText: "80% remaining",
                                  subtitle: nil, progress: 0.8, style: .progress)
        #expect(missing.displaySubtitle == nil)
        let fable = UsageMetric(key: "weekly-fable", title: "Fable", valueText: "90% remaining",
                                subtitle: "Separate weekly limit for Fable", progress: 0.9, style: .progress)
        #expect(fable.displaySubtitle == "Separate Fable limit")
    }
}
