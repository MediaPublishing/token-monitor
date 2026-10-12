import Foundation
import Testing
@testable import TokenMonitorCore

struct AnalyticsPresentationTests {
    @Test func threadsSortByUsageThenStableID() {
        var group = AnalyticsGroup(id: "example", title: "Example")
        group.threadTokens = ["codex:z": .init(input: 100), "claude:a": .init(input: 100), "codex:b": .init(input: 200)]
        #expect(group.sortedThreadIDs == ["codex:b", "claude:a", "codex:z"])
    }

    @Test func topicsAreMeaningfulOnlyForUsageInTheSelectedPeriod() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = AnalyticsSnapshot(
            threads: ["a": .init(id: "a", provider: .codex, projectKey: "/A"),
                      "b": .init(id: "b", provider: .claudeCode, projectKey: "/B")],
            usage: [.init(id: "event-a", threadID: "a", date: now, tokens: .init(input: 200)),
                    .init(id: "event-b", threadID: "b", date: now.addingTimeInterval(-10), tokens: .init(input: 100))]
        )
        #expect(!snapshot.hasMeaningfulTopics(since: .distantPast, until: now, assignments: [:]))
        let assignments = ["/A": AnalyticsAssignment(topic: "Development")]
        #expect(snapshot.hasMeaningfulTopics(since: .distantPast, until: now, assignments: assignments))
        #expect(!snapshot.hasMeaningfulTopics(since: now.addingTimeInterval(-5), until: now, assignments: assignments))
        let topics = snapshot.groups(grouping: .topics, since: .distantPast, until: now, assignments: assignments)
        #expect(topics.reduce(0) { $0 + $1.tokens.total } == 300)
    }
}
