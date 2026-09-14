import Foundation
import Testing
@testable import TokenMonitorCore

struct DashboardReducerTests {
    @Test func enabledOpenCodeTriesExistingSessionOnceOnLaunchWithoutASnapshot() {
        let status = DashboardState.initial(lastSnapshots: [:]).service(.openCodeGo)
        #expect(!status.shouldSkipAutomaticRefresh(trigger: .launch))
        #expect(status.shouldSkipAutomaticRefresh(trigger: .background))
        #expect(!status.shouldSkipAutomaticRefresh(trigger: .manual))
        #expect(!status.shouldSkipAutomaticRefresh(trigger: .login))
    }

    @Test func missingChatGPTAndClaudeAccountsDoNotRefreshUntilConnected() {
        let state = DashboardState.initial(lastSnapshots: [:])
        for service in [ServiceKind.chatGPT, .claude] {
            #expect(state.service(service).shouldSkipAutomaticRefresh(trigger: .launch))
            #expect(state.service(service).shouldSkipAutomaticRefresh(trigger: .background))
            #expect(!state.service(service).shouldSkipAutomaticRefresh(trigger: .login))
        }
    }

    @Test func firstLaunchRequiresConnectionForBothServices() {
        let state = DashboardState.initial(lastSnapshots: [:])

        #expect(state.service(.claude).connectionStatus == .authRequired)
        #expect(state.service(.chatGPT).connectionStatus == .authRequired)
    }

    @Test func successfulRefreshMarksServiceHealthyAndStoresSnapshot() {
        var state = DashboardState.initial(lastSnapshots: [:])
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ServiceSnapshot(
            service: .chatGPT,
            capturedAt: now,
            pageTitle: "Usage dashboard",
            url: "https://chatgpt.com/codex/cloud/settings/usage",
            metrics: [
                UsageMetric(
                    key: "weekly-limit",
                    title: "Weekly usage limit",
                    valueText: "100% remaining",
                    subtitle: nil,
                    progress: 1.0,
                    style: .progress
                )
            ]
        )

        DashboardReducer.reduce(&state, event: .service(.chatGPT, .refreshStarted(trigger: .manual)), now: now)
        #expect(state.service(.chatGPT).refreshState == .refreshing(trigger: .manual))
        #expect(state.service(.chatGPT).connectionStatus == .refreshing)

        DashboardReducer.reduce(&state, event: .service(.chatGPT, .refreshSucceeded(snapshot)), now: now)
        #expect(state.service(.chatGPT).connectionStatus == .healthy)
        #expect(state.service(.chatGPT).snapshot == snapshot)
        #expect(state.lastRefresh == now)
    }

    @Test func refreshFailureKeepsLastSnapshotAndMarksServiceStale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: now,
            pageTitle: "Usage",
            url: "https://claude.ai/settings/usage",
            metrics: [
                UsageMetric(
                    key: "weekly-all-models",
                    title: "All models",
                    valueText: "100% used",
                    subtitle: "Resets in 10 hr 14 min",
                    progress: 1.0,
                    style: .progress
                )
            ]
        )
        var state = DashboardState.initial(lastSnapshots: [.claude: snapshot])

        DashboardReducer.reduce(&state, event: .service(.claude, .refreshFailed(message: "Network timeout")), now: now.addingTimeInterval(60))

        #expect(state.service(.claude).connectionStatus == .stale)
        #expect(state.service(.claude).snapshot == snapshot)
        #expect(state.service(.claude).refreshState == .stale(lastSuccess: now, message: "Network timeout"))
    }

    @Test func authRequiredWithSnapshotKeepsLastSnapshotVisibleAndMarksStale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ServiceSnapshot(
            service: .claude,
            capturedAt: now,
            pageTitle: "Usage",
            url: "https://claude.ai/settings/usage",
            metrics: []
        )
        var state = DashboardState.initial(lastSnapshots: [.claude: snapshot])

        DashboardReducer.reduce(&state, event: .service(.claude, .authRequired(message: "Claude login required")), now: now)

        #expect(state.service(.claude).connectionStatus == .stale)
        #expect(state.service(.claude).snapshot == snapshot)
        #expect(state.service(.claude).refreshState == .stale(lastSuccess: now, message: "Claude login required"))
    }

    @Test func disconnectRemovesThePreviousAccountSnapshot() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ServiceSnapshot(
            service: .openCodeGo,
            capturedAt: now,
            pageTitle: "OpenCode Go",
            url: "https://opencode.ai/workspace/previous/go",
            metrics: []
        )
        var state = DashboardState.initial(lastSnapshots: [.openCodeGo: snapshot])

        DashboardReducer.reduce(
            &state,
            event: .service(.openCodeGo, .disconnected(message: "Connect account")),
            now: now
        )

        #expect(state.service(.openCodeGo).snapshot == nil)
        #expect(state.service(.openCodeGo).connectionStatus == .authRequired)
        #expect(state.service(.openCodeGo).refreshState == .authRequired(message: "Connect account"))
    }
}
