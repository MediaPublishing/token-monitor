import Foundation

public enum AnalyticsProvider: String, Codable, CaseIterable, Sendable {
    case codex, claudeCode

    public var title: String { self == .codex ? "Codex" : "Claude Code" }
}

public enum AnalyticsGrouping: String, CaseIterable, Sendable {
    case projects, topics
}

public enum AnalyticsPeriod: Int, CaseIterable, Sendable {
    case week = 7, month = 30

    public func start(at now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -(rawValue - 1), to: calendar.startOfDay(for: now)) ?? now
    }
}

public struct RecordedTokens: Codable, Equatable, Sendable {
    public var input: Int64
    public var cacheRead: Int64
    public var cacheWrite: Int64
    public var output: Int64
    public var total: Int64 { input + cacheRead + cacheWrite + output }

    public init(input: Int64 = 0, cacheRead: Int64 = 0, cacheWrite: Int64 = 0, output: Int64 = 0) {
        self.input = input
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.output = output
    }

    public func adding(_ other: Self) -> Self {
        Self(input: input + other.input, cacheRead: cacheRead + other.cacheRead,
             cacheWrite: cacheWrite + other.cacheWrite, output: output + other.output)
    }

    public func increase(over previous: Self) -> Self? {
        guard input >= previous.input, cacheRead >= previous.cacheRead,
              cacheWrite >= previous.cacheWrite, output >= previous.output else { return nil }
        return Self(input: input - previous.input, cacheRead: cacheRead - previous.cacheRead,
                    cacheWrite: cacheWrite - previous.cacheWrite, output: output - previous.output)
    }
}

public struct AnalyticsThread: Equatable, Sendable {
    public var id: String
    public var parentID: String?
    public var provider: AnalyticsProvider
    public var projectKey: String
    public var createdAt: Date?

    public init(id: String, parentID: String? = nil, provider: AnalyticsProvider,
                projectKey: String, createdAt: Date? = nil) {
        self.id = id
        self.parentID = parentID
        self.provider = provider
        self.projectKey = projectKey
        self.createdAt = createdAt
    }
}

public struct AnalyticsUsage: Equatable, Sendable {
    public var id: String
    public var threadID: String
    public var date: Date
    public var tokens: RecordedTokens
    public var model: String

    public init(id: String, threadID: String, date: Date, tokens: RecordedTokens, model: String = "") {
        self.id = id
        self.threadID = threadID
        self.date = date
        self.tokens = tokens
        self.model = model
    }
}

public struct AnalyticsAssignment: Codable, Equatable, Sendable {
    public var projectName: String
    public var topic: String

    public init(projectName: String = "", topic: String = "") {
        self.projectName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.topic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct AnalyticsSourceStatus: Sendable {
    public let provider: AnalyticsProvider
    public let files: Int
    public let state: String
    public let omitted: Int

    public init(provider: AnalyticsProvider, files: Int, state: String, omitted: Int = 0) {
        self.provider = provider
        self.files = files
        self.state = state
        self.omitted = omitted
    }
}

public struct AnalyticsSnapshot: Sendable {
    public var threads: [String: AnalyticsThread]
    public var usage: [AnalyticsUsage]
    public var sources: [AnalyticsSourceStatus]
    public var capturedAt: Date

    public init(threads: [String: AnalyticsThread] = [:], usage: [AnalyticsUsage] = [],
                sources: [AnalyticsSourceStatus] = [], capturedAt: Date = Date()) {
        self.threads = threads
        self.usage = usage
        self.sources = sources
        self.capturedAt = capturedAt
    }

    public func rootThread(for id: String) -> AnalyticsThread? {
        guard var thread = threads[id] else { return nil }
        var visited: Set<String> = [id]
        while let parentID = thread.parentID, let parent = threads[parentID], !visited.contains(parentID) {
            visited.insert(parentID)
            thread = parent
        }
        return thread
    }

    public func groups(grouping: AnalyticsGrouping, since: Date, until: Date = .distantFuture,
                       assignments: [String: AnalyticsAssignment] = [:]) -> [AnalyticsGroup] {
        var result: [String: AnalyticsGroup] = [:]
        // The same server message or cumulative snapshot can occur in copied/archived logs.
        var unique: [String: AnalyticsUsage] = [:]
        for event in usage {
            if unique[event.id].map({ $0.tokens.total >= event.tokens.total }) != true { unique[event.id] = event }
        }
        for event in unique.values where event.date >= since && event.date <= until && event.tokens.total > 0 {
            guard let thread = rootThread(for: event.threadID) else { continue }
            let assignment = assignments[thread.projectKey] ?? AnalyticsAssignment()
            let defaultName = thread.projectKey.isEmpty ? "Nicht zugeordnet" : URL(fileURLWithPath: thread.projectKey).lastPathComponent
            let projectName = assignment.projectName.isEmpty ? defaultName : assignment.projectName
            let title = grouping == .projects ? projectName : (assignment.topic.isEmpty ? "Nicht zugeordnet" : assignment.topic)
            let key: String
            if grouping == .topics { key = "topic:" + title.lowercased() }
            else if !assignment.projectName.isEmpty { key = "project:" + projectName.lowercased() }
            else { key = "path:" + thread.projectKey }
            var group = result[key] ?? AnalyticsGroup(id: key, title: title)
            group.tokens = group.tokens.adding(event.tokens)
            group.projectKeys.insert(thread.projectKey)
            group.threadTokens[thread.id] = (group.threadTokens[thread.id] ?? RecordedTokens()).adding(event.tokens)
            group.providerTokens[thread.provider] = (group.providerTokens[thread.provider] ?? RecordedTokens()).adding(event.tokens)
            result[key] = group
        }
        return result.values.sorted { $0.tokens.total == $1.tokens.total ? $0.title < $1.title : $0.tokens.total > $1.tokens.total }
    }
}

public struct AnalyticsGroup: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var tokens = RecordedTokens()
    public var projectKeys: Set<String> = []
    public var threadTokens: [String: RecordedTokens] = [:]
    public var providerTokens: [AnalyticsProvider: RecordedTokens] = [:]
    public var threadCount: Int { threadTokens.count }

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
