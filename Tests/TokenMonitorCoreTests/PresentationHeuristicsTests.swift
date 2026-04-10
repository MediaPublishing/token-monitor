import Foundation
import Testing
@testable import TokenMonitorCore

struct PresentationHeuristicsTests {
    @Test func dashboardOrdersClaudeBeforeChatGPT() {
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

        #expect(state.services.map(\.service) == [.claude, .chatGPT])
    }

    @Test func capacityScoreUsesMostConstrainedMetricForClaude() {
        let snapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: .now,
            pageTitle: "Claude",
            url: "https://claude.ai/settings/usage",
            metrics: [
                UsageMetric(key: "current-session", title: "Current session", valueText: "0% used", subtitle: nil, progress: 0, style: .progress),
                UsageMetric(key: "weekly-all-models", title: "All models", valueText: "100% used", subtitle: nil, progress: 1, style: .progress),
                UsageMetric(key: "weekly-sonnet", title: "Sonnet only", valueText: "17% used", subtitle: nil, progress: 0.17, style: .progress)
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
}
