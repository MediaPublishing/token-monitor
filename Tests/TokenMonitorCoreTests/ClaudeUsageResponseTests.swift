import Foundation
import Testing
@testable import TokenMonitorCore

struct ClaudeUsageResponseTests {
    @Test(arguments: ["https://claude.ai/settings/usage", "https://claude.ai/new#settings/usage",
                      "https://claude.ai/chat/synthetic#settings/usage", "https://www.claude.ai/#/settings/usage/"])
    func modalUsageRoutesCanFinishConnection(_ url: String) {
        #expect(ClaudeUsageNavigation.isUsageURL(url))
    }

    @Test(arguments: ["https://claude.ai/new", "https://claude.ai/login", "http://claude.ai/settings/usage",
                      "https://claude.ai.attacker.invalid/settings/usage", "https://attacker.invalid/?next=https://claude.ai/settings/usage",
                      "https://claude.ai:444/settings/usage", "https://claude.ai/new#settings/general"])
    func unrelatedRoutesNeverSignalUsageReadiness(_ url: String) {
        #expect(!ClaudeUsageNavigation.isUsageURL(url))
    }

    private func response(_ json: String) throws -> ClaudeUsageResponse {
        try JSONDecoder().decode(ClaudeUsageResponse.self, from: Data(json.utf8))
    }

    @Test func structuredQuotaSurvivesUnreadableDOM() throws {
        let page = ServicePageExtract(service: .claude, pageTitle: "Claude",
            url: "https://claude.ai/new", bodyText: "Synthetic account page without limit sections", segments: [])
        #expect(throws: UsageParseError.self) { try ClaudeUsageParser().parse(extract: page, now: .now) }
        let result = try response(#"{"outcome":"available","stage":"usage","httpStatus":200,"windows":[{"scope":"session","used":37.5},{"scope":"weekly","used":100,"resetsAt":"2026-11-20T05:00:00.000Z"}]}"#)
        let snapshot = try result.snapshot(now: .now)
        #expect(snapshot.statusMenuSessionScore == 0.625)
        #expect(snapshot.statusMenuTotalScore == 0)
        #expect(snapshot.metric(for: "weekly-all-models")?.subtitle?.hasPrefix("Reset: ") == true)
    }

    @Test(arguments: ["session", "weekly"])
    func singleRealQuotaDoesNotCreateTheOther(_ scope: String) throws {
        let result = try response("{\"outcome\":\"available\",\"stage\":\"usage\",\"httpStatus\":200,\"windows\":[{\"scope\":\"\(scope)\",\"used\":0}]}")
        let snapshot = try result.snapshot(now: .now)
        #expect(snapshot.metrics.count == 1)
        #expect(snapshot.statusMenuSessionScore == (scope == "session" ? 1 : nil))
        #expect(snapshot.statusMenuTotalScore == (scope == "weekly" ? 1 : nil))
    }

    @Test func explicitNoQuotaClearsOldBarsWithoutPretendingUnlimited() throws {
        let result = try response(#"{"outcome":"notReported","stage":"usage","httpStatus":200,"confirmedEmpty":true,"windows":[]}"#)
        let empty = try result.snapshot(now: .now)
        let account = MonitoredAccount.primary(for: .claude)
        var state = DashboardState.initial(accounts: [account])
        let old = ServiceSnapshot(service: .claude, capturedAt: .distantPast, pageTitle: "Usage", url: "",
            metrics: [UsageMetric(key: "weekly-all-models", title: "All models", valueText: "12% remaining", subtitle: nil, progress: 0.12, style: .progress)])
        DashboardReducer.reduce(&state, event: .account(account.id, .refreshSucceeded(old)))
        DashboardReducer.reduce(&state, event: .account(account.id, .refreshSucceeded(empty)))
        #expect(state.account(account.id)?.snapshot?.quotaAvailability == .notReported)
        #expect(state.account(account.id)?.connectionStatus == .healthy)
        #expect(empty.metrics.isEmpty)
        #expect(empty.statusMenuSessionScore == nil && empty.statusMenuTotalScore == nil)
        #expect(empty.capacityScore == nil)
    }

    @Test(arguments: [
        #"{"outcome":"notReported","stage":"usage","httpStatus":200}"#,
        #"{"outcome":"notReported","stage":"usage","httpStatus":403,"confirmedEmpty":true}"#,
        #"{"outcome":"notReported","stage":"organizations","httpStatus":200,"confirmedEmpty":true}"#,
        #"{"outcome":"available","stage":"usage","httpStatus":200,"windows":[]}"#,
        #"{"outcome":"available","stage":"usage","httpStatus":200,"windows":[{"scope":"session","used":101}]}"#,
        #"{"outcome":"available","stage":"usage","httpStatus":200,"windows":[{"scope":"session","used":-1}]}"#,
        #"{"outcome":"available","stage":"usage","httpStatus":200,"windows":[{"scope":"session","used":1},{"scope":"session","used":2}]}"#,
        #"{"outcome":"available","stage":"usage","httpStatus":200,"windows":[{"scope":"session","used":1,"resetsAt":"PRIVATE_NOT_A_DATE"}]}"#
    ]) func invalidResponsesNeverBecomeFreshCapacity(_ json: String) throws {
        let result = try response(json)
        #expect(throws: UsageParseError.self) { try result.snapshot(now: .now) }
    }

    @Test func oldSnapshotsRemainDecodable() throws {
        let snapshot = ServiceSnapshot(service: .claude, capturedAt: .now, pageTitle: "Usage", url: "", metrics: [])
        let json = try JSONEncoder().encode(snapshot)
        #expect(!String(decoding: json, as: UTF8.self).contains("quotaAvailability"))
        #expect(try JSONDecoder().decode(ServiceSnapshot.self, from: json).quotaAvailability == nil)
    }

    @Test func isolatedJavaScriptFixturesPass() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", root.appendingPathComponent("scripts/check-claude-usage-api.mjs").path]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
