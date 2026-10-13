import Foundation
import CoreFoundation
import Darwin

public struct AnalyticsParsedLog: Sendable {
    public var threads: [String: AnalyticsThread] = [:]
    public var usage: [AnalyticsUsage] = []
    public var omitted = 0
}

/// Reads only token counters and routing metadata. It never retains message content.
public struct AnalyticsLogParser {
    private let provider: AnalyticsProvider
    private let fallbackID: String
    private let parentID: String?
    private let since: Date
    private var result = AnalyticsParsedLog()
    private var threadID = ""
    private var previous: RecordedTokens?
    private var model = ""
    private var claudeMessages: [String: AnalyticsUsage] = [:]

    public init(provider: AnalyticsProvider, fallbackID: String, parentID: String? = nil, since: Date) {
        self.provider = provider
        self.fallbackID = fallbackID
        self.parentID = parentID
        self.since = since
    }

    public mutating func consume(_ data: Data) {
        guard let line = String(data: data, encoding: .utf8) else { result.omitted += 1; return }
        // Skip conversation-only records before JSON decoding their bodies.
        guard line.contains("session_meta") || line.contains("turn_context") || line.contains("token_count") ||
                (provider == .claudeCode && line.contains("\"usage\"")) else { return }
        guard let row = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            result.omitted += 1; return
        }
        if provider == .codex { consumeCodex(row) } else { consumeClaude(row) }
    }

    public mutating func noteOmittedLine() { result.omitted += 1 }

    public func finish() -> AnalyticsParsedLog {
        var finished = result
        finished.usage += claudeMessages.values
        return finished
    }

    private mutating func consumeCodex(_ row: [String: Any]) {
        let type = row["type"] as? String
        guard let payload = row["payload"] as? [String: Any] else { return }
        if type == "session_meta" {
            guard let id = payload["id"] as? String ?? payload["session_id"] as? String else { return }
            threadID = "codex:" + id
            let source = payload["source"] as? [String: Any]
            let subagent = source?["subagent"] as? [String: Any]
            let spawn = subagent?["thread_spawn"] as? [String: Any]
            // Forks are separate threads. Only agent-spawn metadata rolls up into a parent.
            let parent = subagent != nil ? (payload["parent_thread_id"] as? String ?? spawn?["parent_thread_id"] as? String) : nil
            result.threads[threadID] = AnalyticsThread(id: threadID, parentID: parent.map { "codex:" + $0 },
                provider: .codex, projectKey: payload["cwd"] as? String ?? "", createdAt: date(payload["timestamp"]))
            return
        }
        if type == "turn_context" { model = payload["model"] as? String ?? model; return }
        guard type == "event_msg", payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let values = info["total_token_usage"] as? [String: Any],
              let total = codexTokens(values), let timestamp = date(row["timestamp"]), !threadID.isEmpty else { return }
        let delta: RecordedTokens
        if let previous {
            guard let increase = total.increase(over: previous) else {
                self.previous = total
                result.omitted += 1
                return
            }
            delta = increase
        } else if let lastValues = info["last_token_usage"] as? [String: Any], let last = codexTokens(lastValues),
                  total.increase(over: last) != nil {
            delta = last
            if total != last { result.omitted += 1 }
        } else {
            // Without a baseline, a cumulative value cannot be placed in this period.
            previous = total
            result.omitted += 1
            return
        }
        previous = total
        guard timestamp >= since, timestamp >= (result.threads[threadID]?.createdAt ?? .distantPast), delta.total > 0 else { return }
        let signature = "\(total.input):\(total.cacheRead):\(total.cacheWrite):\(total.output)"
        result.usage.append(AnalyticsUsage(id: threadID + ":" + signature + ":" + String(timestamp.timeIntervalSince1970), threadID: threadID,
                                          date: timestamp, tokens: delta, model: model))
    }

    private mutating func consumeClaude(_ row: [String: Any]) {
        guard row["type"] as? String == "assistant", let message = row["message"] as? [String: Any],
              let values = message["usage"] as? [String: Any],
              let id = message["id"] as? String,
              let timestamp = date(row["timestamp"]), timestamp >= since,
              let tokens = claudeTokens(values) else { return }
        let session = row["sessionId"] as? String ?? fallbackID
        threadID = parentID == nil ? "claude:" + session : "claude:" + parentID! + ":" + fallbackID
        result.threads[threadID] = AnalyticsThread(id: threadID, parentID: parentID.map { "claude:" + $0 },
            provider: .claudeCode, projectKey: row["cwd"] as? String ?? "")
        let key = "claude:message:" + id
        let event = AnalyticsUsage(id: key, threadID: threadID, date: timestamp, tokens: tokens,
                                   model: message["model"] as? String ?? "")
        if let old = claudeMessages[key], old.tokens.total >= tokens.total { return }
        claudeMessages[key] = event
    }

    private func number(_ row: [String: Any], _ key: String, optional: Bool = false) -> Int64? {
        guard let raw = row[key] else { return optional ? 0 : nil }
        guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite, value.doubleValue.rounded() == value.doubleValue else { return nil }
        let count = value.int64Value
        return count >= 0 && count <= 1_000_000_000_000 ? count : nil
    }

    private func codexTokens(_ row: [String: Any]) -> RecordedTokens? {
        guard let input = number(row, "input_tokens"), let output = number(row, "output_tokens"),
              let read = number(row, "cached_input_tokens", optional: true),
              let write = number(row, "cache_write_input_tokens", optional: true), input >= read + write else { return nil }
        // Codex cached input and reasoning output are subsets, not extra usage.
        return RecordedTokens(input: input - read - write, cacheRead: read, cacheWrite: write, output: output)
    }

    private func claudeTokens(_ row: [String: Any]) -> RecordedTokens? {
        guard let input = number(row, "input_tokens"), let output = number(row, "output_tokens"),
              let read = number(row, "cache_read_input_tokens", optional: true),
              let write = number(row, "cache_creation_input_tokens", optional: true) else { return nil }
        return RecordedTokens(input: input, cacheRead: read, cacheWrite: write, output: output)
    }

    private func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)) ??
            (try? Date.ISO8601FormatStyle().parse(text))
    }
}

public actor AnalyticsLogScanner {
    private struct CachedLog {
        let size: Int
        let modified: Date
        let since: Date
        let parsed: AnalyticsParsedLog
    }
    private var cache: [URL: CachedLog] = [:]

    public init() {}

    public func clear() { cache.removeAll() }

    public func scan(home: URL, providers: Set<AnalyticsProvider>, since: Date,
                     now: Date = Date(), maximumFiles: Int = 1500,
                     maximumBytes: Int = 512 * 1024 * 1024) throws -> AnalyticsSnapshot {
        var snapshot = AnalyticsSnapshot(capturedAt: now)
        let selectedRoots = providers.flatMap { provider in
            provider == .codex ? [home.appendingPathComponent(".codex/sessions"), home.appendingPathComponent(".codex/archived_sessions")]
                : [home.appendingPathComponent(".claude/projects")]
        }
        cache = cache.filter { file, _ in selectedRoots.contains { file.path.hasPrefix($0.path + "/") } }
        let manager = FileManager.default
        let sourceCount = max(1, providers.count)
        for provider in AnalyticsProvider.allCases where providers.contains(provider) {
            var bytesRead = 0
            var visitedFiles = 0
            let fileBudget = max(0, maximumFiles / sourceCount)
            let byteBudget = max(0, maximumBytes / sourceCount)
            try Task.checkCancellation()
            let roots = provider == .codex
                ? [home.appendingPathComponent(".codex/sessions"), home.appendingPathComponent(".codex/archived_sessions")]
                : [home.appendingPathComponent(".claude/projects")]
            var candidates: [(URL, URLResourceValues)] = []
            var foundRoot = false
            var omitted = 0
            for root in roots {
                guard root.resolvingSymlinksInPath().standardizedFileURL == root.standardizedFileURL else { omitted += 1; continue }
                guard let rootValues = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      rootValues.isDirectory == true, rootValues.isSymbolicLink != true else { continue }
                foundRoot = true
                guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys:
                    [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles], errorHandler: { _, _ in false }) else { omitted += 1; continue }
                var entries = 0
                while let url = enumerator.nextObject() as? URL {
                    entries += 1
                    if entries > 30_000 { omitted += 1; break }
                    try Task.checkCancellation()
                    guard let values = try? url.resourceValues(forKeys:
                        [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]) else { omitted += 1; continue }
                    if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                    guard values.isRegularFile == true, url.pathExtension == "jsonl" else { continue }
                    candidates.append((url, values))
                    if candidates.count >= 10_000 { omitted += 1; break }
                }
            }
            candidates.sort { ($0.1.contentModificationDate ?? .distantPast) > ($1.1.contentModificationDate ?? .distantPast) }
            var scanned = 0
            for (url, values) in candidates {
                try Task.checkCancellation()
                guard visitedFiles < fileBudget else { omitted += 1; continue }
                visitedFiles += 1
                let size = values.fileSize ?? 0
                let modified = values.contentModificationDate ?? .distantPast
                let parsed: AnalyticsParsedLog
                if modified < now.addingTimeInterval(-300), let stored = cache[url],
                   stored.size == size, stored.modified == modified, stored.since <= since {
                    parsed = stored.parsed
                } else {
                    guard size <= 64 * 1024 * 1024, bytesRead + size <= byteBudget else { omitted += 1; continue }
                    do {
                        let parent = provider == .claudeCode && url.deletingLastPathComponent().lastPathComponent == "subagents"
                            ? url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent : nil
                        parsed = try read(url: url, provider: provider, parent: parent, since: since,
                                          byteLimit: min(64 * 1024 * 1024, byteBudget - bytesRead))
                        bytesRead += size
                        cache[url] = CachedLog(size: size, modified: modified, since: since, parsed: parsed)
                    } catch is CancellationError { throw CancellationError() }
                    catch { omitted += 1; continue }
                }
                scanned += 1
                omitted += parsed.omitted
                for (id, var thread) in parsed.threads {
                    thread.projectKey = projectRoot(thread.projectKey, home: home)
                    snapshot.threads[id] = thread
                }
                snapshot.usage += parsed.usage
            }
            snapshot.sources.append(AnalyticsSourceStatus(provider: provider, files: scanned,
                state: !foundRoot ? "No local logs" : (omitted > 0 ? "Partially recorded" : "Local logs"), omitted: omitted))
        }
        return snapshot
    }

    private func projectRoot(_ path: String, home: URL) -> String {
        guard path.hasPrefix("/") else { return "" }
        var current = URL(fileURLWithPath: path).standardizedFileURL
        let original = current
        while current.path != "/" && current.path != home.path {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) { return current.path }
            let parent = current.deletingLastPathComponent()
            if parent.path == home.appendingPathComponent("Projects").path { return current.path }
            current = parent
        }
        return original.path == home.path ? "" : original.path
    }

    private func read(url: URL, provider: AnalyticsProvider, parent: String?, since: Date, byteLimit: Int) throws -> AnalyticsParsedLog {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoPermission) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0, attributes.st_mode & S_IFMT == S_IFREG else {
            throw CocoaError(.fileReadUnknown)
        }
        var parser = AnalyticsLogParser(provider: provider, fallbackID: url.deletingPathExtension().lastPathComponent,
                                        parentID: parent, since: since)
        var pending = Data()
        var discarding = false
        var readBytes = 0
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            readBytes += chunk.count
            guard readBytes <= byteLimit else { throw CocoaError(.fileReadTooLarge) }
            var start = chunk.startIndex
            for index in chunk.indices where chunk[index] == 10 {
                if !discarding {
                    pending.append(chunk[start..<index])
                    if pending.count <= 2 * 1024 * 1024 { parser.consume(pending) } else { parser.noteOmittedLine() }
                }
                pending.removeAll(keepingCapacity: true)
                discarding = false
                start = chunk.index(after: index)
            }
            if !discarding { pending.append(chunk[start..<chunk.endIndex]) }
            if pending.count > 2 * 1024 * 1024 {
                pending.removeAll(keepingCapacity: true)
                discarding = true
                parser.noteOmittedLine()
            }
        }
        // A trailing fragment can be a concurrently appended record; retry on the next scan.
        if !pending.isEmpty || discarding { parser.noteOmittedLine() }
        return parser.finish()
    }
}
