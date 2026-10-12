import Foundation
import Testing
@testable import TokenMonitorCore

struct ProjectAnalyticsTests {
    let since = Date(timeIntervalSince1970: 1_790_000_000)
    let stamp = "2026-10-10T12:00:00Z"

    func parse(_ rows: [[String: Any]], provider: AnalyticsProvider = .codex, parent: String? = nil) throws -> AnalyticsParsedLog {
        var parser = AnalyticsLogParser(provider: provider, fallbackID: "child", parentID: parent, since: since)
        for row in rows { parser.consume(try JSONSerialization.data(withJSONObject: row)) }
        return parser.finish()
    }

    func meta(_ id: String = "one", created: String = "2026-10-10T10:00:00Z", agentParent: String? = nil) -> [String: Any] {
        var payload: [String: Any] = ["id": id, "cwd": "/Projects/demo", "timestamp": created]
        if let agentParent { payload["source"] = ["subagent": ["thread_spawn": ["parent_thread_id": agentParent]]] }
        return ["type": "session_meta", "payload": payload]
    }

    func count(_ input: Any = 100, cached: Int = 40, output: Int = 20, lastInput: Int? = nil, timestamp: String? = nil) -> [String: Any] {
        let tokens: [String: Any] = ["input_tokens": input, "cached_input_tokens": cached, "output_tokens": output,
                                   "reasoning_output_tokens": 10, "total_tokens": 99999]
        var info: [String: Any] = ["total_token_usage": tokens]
        info["last_token_usage"] = lastInput.map { ["input_tokens": $0, "cached_input_tokens": 0, "output_tokens": 5] } ?? tokens
        return ["type": "event_msg", "timestamp": timestamp ?? stamp, "payload": ["type": "token_count", "info": info]]
    }

    func claude(_ id: String = "msg", output: Int = 20, timestamp: String? = nil) -> [String: Any] {
        ["type": "assistant", "sessionId": "parent", "cwd": "/Projects/demo", "timestamp": timestamp ?? stamp,
         "message": ["id": id, "model": "example", "usage": ["input_tokens": 10, "output_tokens": output,
            "cache_read_input_tokens": 30, "cache_creation_input_tokens": 40,
            "cache_creation": ["ephemeral_1h_input_tokens": 40], "output_tokens_details": ["thinking_tokens": 5]]]]
    }

    @Test func cumulativeCodexDeduplicatesAndDoesNotAddCacheReasoningOrContextEstimate() throws {
        let log = try parse([meta(), count(), count(), count(150, cached: 60, output: 30)])
        #expect(log.usage.reduce(0) { $0 + $1.tokens.total } == 180)
        #expect(log.usage.first?.tokens == RecordedTokens(input: 60, cacheRead: 40, output: 20))
        #expect(log.usage.count == 2)
    }

    @Test func inheritedBaselineOnlyCountsLatestTurnAndCounterResetsAreConservative() throws {
        let log = try parse([meta(), count(1000, lastInput: 10), count(1100, output: 30), count(10, cached: 0, output: 1)])
        #expect(log.usage.reduce(0) { $0 + $1.tokens.total } == 125)
        #expect(log.omitted == 2)
    }

    @Test func copiedForkHistoryBeforeCreationIsNotChargedAgain() throws {
        let log = try parse([meta("fork", created: "2026-10-10T13:00:00Z"), count(),
                             count(150, cached: 60, output: 30, timestamp: "2026-10-10T14:00:00Z")])
        #expect(log.usage.reduce(0) { $0 + $1.tokens.total } == 60)
    }

    @Test func malformedNumbersAndUnsupportedRecordsDoNotInventUsage() throws {
        let log = try parse([meta(), count(true, cached: 0), count(1.5, cached: 0), count(-1, cached: 0)])
        #expect(log.usage.isEmpty)
        var parser = AnalyticsLogParser(provider: .codex, fallbackID: "x", since: since)
        parser.consume(Data("{\"token_count\":bad}".utf8))
        #expect(parser.finish().omitted == 1)
    }

    @Test func claudeBlocksAndCopiedFilesCountMessageOnlyOnce() throws {
        let log = try parse([claude(), claude(), claude(output: 25)], provider: .claudeCode)
        #expect(log.usage.count == 1)
        #expect(log.usage.first?.tokens.total == 105)
        let snapshot = AnalyticsSnapshot(threads: log.threads, usage: log.usage + log.usage)
        #expect(snapshot.groups(grouping: .projects, since: since).first?.tokens.total == 105)
    }

    @Test func agentsRollUpAndTopicAssignmentsAggregateWithoutMergingSameFolderNames() throws {
        var parent = try parse([meta("parent"), count()])
        let child = try parse([meta("child", agentParent: "parent"), count(50, cached: 10, output: 5)])
        parent.threads.merge(child.threads) { _, new in new }
        var snapshot = AnalyticsSnapshot(threads: parent.threads, usage: parent.usage + child.usage)
        let groups = snapshot.groups(grouping: .projects, since: since)
        #expect(groups.first?.threadCount == 1)
        #expect(groups.first?.tokens.total == 175)
        let other = AnalyticsThread(id: "other", provider: .claudeCode, projectKey: "/Elsewhere/demo")
        snapshot.threads[other.id] = other
        snapshot.usage.append(AnalyticsUsage(id: "other-use", threadID: other.id, date: Date(), tokens: RecordedTokens(input: 10)))
        #expect(snapshot.groups(grouping: .projects, since: since).count == 2)
        let topics = snapshot.groups(grouping: .topics, since: since, assignments: ["/Projects/demo": .init(topic: "Bauen"), "/Elsewhere/demo": .init(topic: "Bauen")])
        #expect(topics.count == 1)
        #expect(topics.first?.tokens.total == 185)
        #expect(topics.first?.providerTokens[.claudeCode]?.total == 10)
    }

    @Test func periodFilteringAndMissingParentsStayHonest() throws {
        let log = try parse([meta("child", agentParent: "missing"), count()])
        let snapshot = AnalyticsSnapshot(threads: log.threads, usage: log.usage)
        #expect(snapshot.groups(grouping: .projects, since: .distantFuture).isEmpty)
        #expect(snapshot.groups(grouping: .projects, since: since, until: since).isEmpty)
        #expect(snapshot.groups(grouping: .projects, since: since).first?.threadCount == 1)
    }

    @Test func fallbackLabelsAreEnglishWithoutTranslatingUserAssignments() {
        let thread = AnalyticsThread(id: "one", provider: .codex, projectKey: "")
        let usage = AnalyticsUsage(id: "usage", threadID: thread.id, date: since, tokens: RecordedTokens(input: 10))
        let snapshot = AnalyticsSnapshot(threads: [thread.id: thread], usage: [usage])
        #expect(snapshot.groups(grouping: .projects, since: since).first?.title == "Unassigned")
        #expect(snapshot.groups(grouping: .topics, since: since).first?.title == "Unassigned")
        let assignments = ["": AnalyticsAssignment(projectName: "Mein Projekt", topic: "Entwicklung")]
        #expect(snapshot.groups(grouping: .projects, since: since, assignments: assignments).first?.title == "Mein Projekt")
        #expect(snapshot.groups(grouping: .topics, since: since, assignments: assignments).first?.title == "Entwicklung")
    }

    @Test func scannerSkipsSymlinksAndReportsLimitsWithoutReadingDisabledSources() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let root = home.appendingPathComponent(".codex/sessions")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try [meta(), count()].map { try JSONSerialization.data(withJSONObject: $0) + Data([10]) }.reduce(Data(), +)
        try data.write(to: root.appendingPathComponent("real.jsonl"))
        try FileManager.default.setAttributes([.modificationDate: since.addingTimeInterval(-1000)], ofItemAtPath: root.appendingPathComponent("real.jsonl").path)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.jsonl"), withDestinationURL: root.appendingPathComponent("real.jsonl"))
        let scanner = AnalyticsLogScanner()
        let disabled = try await scanner.scan(home: home, providers: [], since: since)
        #expect(disabled.sources.isEmpty && disabled.usage.isEmpty)
        let result = try await scanner.scan(home: home, providers: [.codex], since: since)
        #expect(result.sources.first?.files == 1)
        #expect(result.sources.first?.state == "Local logs")
        #expect(result.groups(grouping: .projects, since: since).first?.tokens.total == 120)
        let limited = try await AnalyticsLogScanner().scan(home: home, providers: [.codex], since: since, maximumBytes: 1)
        #expect(limited.usage.isEmpty)
        #expect(limited.sources.first?.omitted == 1)
        #expect(limited.sources.first?.state == "Partially recorded")
    }

    @Test func scannerRejectsLinkedAncestorsAndTrailingFragments() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let actual = home.appendingPathComponent("actual/sessions")
        try FileManager.default.createDirectory(at: actual, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".codex"), withDestinationURL: home.appendingPathComponent("actual"))
        let scanner = AnalyticsLogScanner()
        let rejected = try await scanner.scan(home: home, providers: [.codex], since: since)
        #expect(rejected.usage.isEmpty)
        #expect(rejected.sources.first?.files == 0)
        #expect(rejected.sources.first?.state == "No local logs")
        try FileManager.default.removeItem(at: home.appendingPathComponent(".codex"))
        let root = home.appendingPathComponent(".codex/sessions")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{\"token_count\":".utf8).write(to: root.appendingPathComponent("partial.jsonl"))
        let partial = try await scanner.scan(home: home, providers: [.codex], since: since)
        #expect(partial.sources.first?.omitted == 1)
    }

    @Test func cancellationIsPropagated() async throws {
        let task = Task {
            try Task.checkCancellation()
            return try await AnalyticsLogScanner().scan(home: FileManager.default.temporaryDirectory, providers: [.codex], since: since)
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled scan must not return a snapshot") }
        catch is CancellationError { }
    }
}
