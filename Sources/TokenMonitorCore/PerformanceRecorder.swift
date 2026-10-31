import Darwin
import Foundation

public enum PerformanceActivity: String, Codable, Sendable {
    case providerRefresh, pageExtraction, usageParsing, loginProbe, analysisScan, analysisGrouping
}

public struct PerformanceCapturePolicy: Sendable {
    public var threshold: Double
    public var consecutiveSamples: Int
    public var cooldown: TimeInterval
    private var highSamples = 0
    private var lastCapture: TimeInterval?

    public init(threshold: Double = 80, consecutiveSamples: Int = 3, cooldown: TimeInterval = 600) {
        self.threshold = threshold
        self.consecutiveSamples = max(1, consecutiveSamples)
        self.cooldown = max(0, cooldown)
    }

    public mutating func observe(cpuPercent: Double, uptime: TimeInterval) -> Bool {
        highSamples = cpuPercent.isFinite && cpuPercent >= threshold ? highSamples + 1 : 0
        guard highSamples >= consecutiveSamples,
              lastCapture.map({ uptime - $0 >= cooldown }) ?? true else { return false }
        captured(at: uptime)
        return true
    }

    public mutating func captured(at uptime: TimeInterval) {
        highSamples = 0
        lastCapture = uptime
    }
}

public struct PerformanceMeasurement: Codable, Sendable {
    public let date: Date
    public let cpuPercent: Double
    public let residentMB: Double
    public let threads: Int
    public let mainThreadDelayMS: Double
}

private struct PerformanceEvent: Codable, Sendable {
    let date: Date
    let activity: PerformanceActivity
    let provider: ServiceKind?
    let reader: Int?
    let durationMS: Double?
}

private struct PerformanceArchive: Codable, Sendable {
    var measurements: [PerformanceMeasurement] = []
    var events: [PerformanceEvent] = []
    var profile = ""
    var profileStatus = "No stack profile recorded yet."
    var profileDate: Date?
    var highCPUProfile: String?
    var highCPUProfileDate: Date?
    var version = ""
}

public enum PerformanceProfileRedaction {
    public static func callGraph(from raw: String) -> String {
        guard let start = raw.range(of: "Call graph:") else { return "No call graph was available." }
        var graph = String(raw[start.upperBound...])
        for marker in ["Total number in stack", "Binary Images:"] {
            if let end = graph.range(of: marker) { graph = String(graph[..<end.lowerBound]) }
        }
        // Only the call graph is kept, never process headers, arguments or binary paths.
        for pattern in [#"/(?:Users|private|Volumes|var|tmp|Applications)/[^\s\)]+"#,
                        #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#] {
            graph = graph.replacingOccurrences(of: pattern, with: "[redacted]", options: .regularExpression)
        }
        return String(graph.prefix(48_000)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// All mutable state is confined to the utility queue; profiling never blocks the main thread.
public final class PerformanceRecorder: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TokenMonitor.performance", qos: .utility)
    private let directory: URL
    private let version: String
    private let stackSamplingAllowed: Bool
    private let interval: TimeInterval
    private var policy: PerformanceCapturePolicy
    private var enabled = false
    private var timer: DispatchSourceTimer?
    private var archive = PerformanceArchive()
    private var previousCPU: (seconds: Double, uptime: Double)?
    private var heartbeatSent: Double?
    private var heartbeatDelay = 0.0
    private var lastPersist = 0.0
    private var activities: [UUID: (PerformanceActivity, ServiceKind?, Int?, Double)] = [:]
    private var readers: [UUID: Int] = [:]
    private var profiler: Process?
    private var captureID = UUID()
    private var completions: [@Sendable () -> Void] = []

    public init(directory: URL, version: String, stackSamplingAllowed: Bool = true,
                interval: TimeInterval = 2, policy: PerformanceCapturePolicy = PerformanceCapturePolicy()) {
        self.directory = directory
        self.version = version
        self.stackSamplingAllowed = stackSamplingAllowed
        self.interval = max(0.1, interval)
        self.policy = policy
        let url = directory.appendingPathComponent("performance-latest.json")
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 512_000,
           let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(PerformanceArchive.self, from: data) {
            archive = saved
            archive.measurements = Array(saved.measurements.suffix(300))
            archive.events = Array(saved.events.suffix(200))
            archive.profile = String(saved.profile.prefix(48_000))
            archive.highCPUProfile = saved.highCPUProfile.map { String($0.prefix(48_000)) }
        }
    }

    deinit {
        timer?.cancel()
        if let profiler, profiler.isRunning { profiler.terminate() }
    }

    public func setEnabled(_ value: Bool) {
        queue.async { [self] in
            guard enabled != value else { return }
            enabled = value
            previousCPU = nil
            heartbeatSent = nil
            if !value {
                timer?.cancel()
                timer = nil
                activities.removeAll()
                if let profiler, profiler.isRunning { profiler.terminate() }
                return
            }
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(200))
            source.setEventHandler { [weak self] in self?.measure() }
            timer = source
            source.resume()
        }
    }

    @discardableResult
    public func begin(_ activity: PerformanceActivity, provider: ServiceKind? = nil, reader: UUID? = nil) -> UUID {
        let token = UUID()
        let now = ProcessInfo.processInfo.systemUptime
        queue.async { [self] in
            guard enabled else { return }
            let alias: Int? = reader.map { id in
                if let existing = readers[id] { return existing }
                let next = readers.count + 1
                readers[id] = next
                return next
            }
            activities[token] = (activity, provider, alias, now)
            appendEvent(PerformanceEvent(date: Date(), activity: activity, provider: provider, reader: alias, durationMS: nil))
        }
        return token
    }

    public func end(_ token: UUID) {
        let now = ProcessInfo.processInfo.systemUptime
        queue.async { [self] in
            guard enabled, let (activity, provider, reader, start) = activities.removeValue(forKey: token) else { return }
            appendEvent(PerformanceEvent(date: Date(), activity: activity, provider: provider, reader: reader,
                                         durationMS: max(0, (now - start) * 1000)))
        }
    }

    public func measure<T>(_ activity: PerformanceActivity, provider: ServiceKind? = nil, reader: UUID? = nil,
                           _ work: () throws -> T) rethrows -> T {
        let token = begin(activity, provider: provider, reader: reader)
        defer { end(token) }
        return try work()
    }

    public func captureNow() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard enabled else { continuation.resume(); return }
                completions.append { continuation.resume() }
                if profiler == nil { capture(reason: "Manual capture") }
            }
        }
    }

    public var summaryText: String {
        queue.sync {
            let last = archive.measurements.last
            let peak = archive.measurements.map(\.cpuPercent).max() ?? 0
            return "Performance recording: \(enabled ? "on" : "off")\n" +
                "App CPU last / peak: \(format(last?.cpuPercent ?? 0))% / \(format(peak))% (100% = one core)\n" +
                "Samples: \(archive.measurements.count); latest: \(last.map { stamp($0.date) } ?? "none")\n" +
                "Stack profile: \(archive.profileStatus)\n" +
                "Save Performance Report includes the local trace. No automatic upload."
        }
    }

    public var reportText: String {
        queue.sync {
            var lines = ["# Token Monitor Performance Report", "Created: \(stamp(Date()))", "App version: \(version)",
                "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "Active CPU cores: \(ProcessInfo.processInfo.activeProcessorCount)",
                "Last saved trace version: \(archive.version)", "Debug recording: \(enabled ? "on" : "off")", "",
                "Own app process only; 100% CPU = one core. WebKit XPC CPU is not attributed here.",
                "No page bodies, URLs, account names, chat content or credentials are collected by this recorder.",
                "Reader numbers are temporary aliases, not account identifiers.", "",
                "## Measurements (up to 300, normally every 2 seconds)",
                "timestamp | app CPU % | resident MB | threads | main-thread delay ms"]
            for item in archive.measurements {
                lines.append("\(stamp(item.date)) | \(format(item.cpuPercent)) | \(format(item.residentMB)) | \(item.threads) | \(format(item.mainThreadDelayMS))")
            }
            lines += ["", "## Activity (up to 200 events)"]
            for event in archive.events {
                let context = event.provider.map { $0.rawValue } ?? "local"
                let reader = event.reader.map { " reader-\($0)" } ?? ""
                let state = event.durationMS.map { "end \(format($0)) ms" } ?? "begin"
                lines.append("\(stamp(event.date)) | \(context)\(reader) | \(event.activity.rawValue) | \(state)")
            }
            lines += ["", "## Latest native stack profile", "Captured: \(archive.profileDate.map(stamp) ?? "none")",
                      archive.profileStatus, archive.profile]
            if let highCPUProfile = archive.highCPUProfile {
                lines += ["", "## Last sustained high-CPU profile (preserved across manual captures)",
                          "Captured: \(archive.highCPUProfileDate.map(stamp) ?? "none")", highCPUProfile]
            }
            lines += ["", "Review this local report before sharing it."]
            return lines.joined(separator: "\n")
        }
    }

    private func measure() {
        guard enabled else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return }
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) +
            Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        defer { previousCPU = (cpu, uptime) }
        guard let old = previousCPU, uptime > old.uptime else { return }
        var task = proc_taskinfo()
        let result = proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size))
        let percent = max(0, (cpu - old.seconds) / (uptime - old.uptime) * 100)
        let lag = heartbeatSent.map { max(heartbeatDelay, (uptime - $0) * 1000) } ?? heartbeatDelay
        archive.measurements.append(PerformanceMeasurement(date: Date(), cpuPercent: percent,
            residentMB: result > 0 ? Double(task.pti_resident_size) / 1_048_576 : 0,
            threads: result > 0 ? Int(task.pti_threadnum) : 0, mainThreadDelayMS: lag))
        archive.measurements = Array(archive.measurements.suffix(300))
        if heartbeatSent == nil {
            heartbeatSent = uptime
            DispatchQueue.main.async { [weak self] in
                let elapsed = (ProcessInfo.processInfo.systemUptime - uptime) * 1000
                self?.queue.async { [weak self] in
                    self?.heartbeatDelay = elapsed
                    self?.heartbeatSent = nil
                }
            }
        }
        if policy.observe(cpuPercent: percent, uptime: uptime), profiler == nil { capture(reason: "Sustained high app CPU", automatic: true) }
        if uptime - lastPersist >= 30 { persist(); lastPersist = uptime }
    }

    private func appendEvent(_ event: PerformanceEvent) {
        archive.events.append(event)
        archive.events = Array(archive.events.suffix(200))
    }

    private func capture(reason: String, automatic: Bool = false) {
        guard enabled, profiler == nil else { return }
        policy.captured(at: ProcessInfo.processInfo.systemUptime)
        guard stackSamplingAllowed else {
            archive.profileStatus = "Native stack sampling is unavailable in this build; measurements remain available."
            completeCapture()
            return
        }
        do {
            try prepareDirectory()
            let raw = directory.appendingPathComponent("performance-work.sample")
            FileManager.default.createFile(atPath: raw.path, contents: Data(), attributes: [.posixPermissions: 0o600])
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
            process.arguments = [String(getpid()), "3", "10", "-file", raw.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            let id = UUID()
            captureID = id
            profiler = process
            archive.profileStatus = "Recording: \(reason)"
            process.terminationHandler = { [weak self] process in
                let status = process.terminationStatus
                self?.queue.async { [weak self] in
                    self?.finishProfile(id: id, status: status, raw: raw, reason: reason, automatic: automatic)
                }
            }
            try process.run()
            queue.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self, self.captureID == id, process.isRunning else { return }
                self.archive.profileStatus = "Stack sampling exceeded its 8-second deadline."
                process.terminate()
                self.queue.asyncAfter(deadline: .now() + 2) {
                    if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
                }
            }
        } catch {
            archive.profileStatus = "Stack sampling could not start. Measurements remain available."
            profiler = nil
            completeCapture()
        }
    }

    private func finishProfile(id: UUID, status: Int32, raw: URL, reason: String, automatic: Bool) {
        guard id == captureID else { return }
        defer { try? Data().write(to: raw) }
        profiler = nil
        guard enabled else { completeCapture(); return }
        archive.profileDate = Date()
        if status == 0, let handle = try? FileHandle(forReadingFrom: raw) {
            let data = try? handle.read(upToCount: 512_000)
            try? handle.close()
            archive.profile = PerformanceProfileRedaction.callGraph(from: data.flatMap { String(data: $0, encoding: .utf8) } ?? "")
            archive.profileStatus = "\(reason); 3 seconds, 10 ms interval."
            if archive.profile == "No call graph was available." || archive.profile.isEmpty {
                archive.profileStatus = "Stack sampling returned no readable call graph; measurements remain available."
            } else if automatic {
                archive.highCPUProfile = archive.profile
                archive.highCPUProfileDate = archive.profileDate
            }
        } else {
            archive.profile = ""
            archive.profileStatus = "Stack sampling failed or was stopped (exit \(status)); measurements remain available."
        }
        completeCapture()
    }

    private func completeCapture() {
        if enabled { persist() }
        let callbacks = completions
        completions.removeAll()
        callbacks.forEach { $0() }
    }

    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func persist() {
        guard enabled else { return }
        do {
            try prepareDirectory()
            archive.version = version
            let data = try JSONEncoder().encode(archive)
            guard data.count <= 512_000 else { return }
            let url = directory.appendingPathComponent("performance-latest.json")
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { /* Diagnostics must not interrupt monitoring. */ }
    }

    private func format(_ value: Double) -> String { String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value) }
    private func stamp(_ date: Date) -> String { date.formatted(.iso8601) }
}
