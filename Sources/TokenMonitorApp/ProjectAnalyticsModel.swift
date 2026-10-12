import Combine
import Foundation
import TokenMonitorCore

@MainActor
final class ProjectAnalyticsModel: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var codexEnabled: Bool
    @Published private(set) var claudeEnabled: Bool
    @Published var grouping: AnalyticsGrouping = .projects { didSet { rebuildGroups() } }
    @Published var period: AnalyticsPeriod = .week { didSet { rebuildGroups() } }
    @Published private(set) var groups: [AnalyticsGroup] = []
    @Published private(set) var sources: [AnalyticsSourceStatus] = []
    @Published private(set) var refreshing = false
    @Published private(set) var capturedAt: Date?
    @Published private(set) var errorText: String?

    private let defaults: UserDefaults
    private let home: URL
    private let assignmentURL: URL
    private let scanner = AnalyticsLogScanner()
    private var snapshot: AnalyticsSnapshot?
    private var assignments: [String: AnalyticsAssignment] = [:]
    private var refreshTask: Task<Void, Never>?
    private var requestID = UUID()
    private var assignmentsReadable = true
    private var assignmentError: String?

    init(defaults: UserDefaults = .standard, home: URL = FileManager.default.homeDirectoryForCurrentUser,
         assignmentURL: URL? = nil) {
        self.defaults = defaults
        self.home = home
        self.assignmentURL = assignmentURL ?? home.appendingPathComponent("Library/Application Support/TokenMonitor/Analytics/assignments.json")
        defaults.register(defaults: ["projectAnalyticsEnabled": false, "analyticsCodexEnabled": true, "analyticsClaudeEnabled": true])
        enabled = defaults.bool(forKey: "projectAnalyticsEnabled")
        codexEnabled = defaults.bool(forKey: "analyticsCodexEnabled")
        claudeEnabled = defaults.bool(forKey: "analyticsClaudeEnabled")
        if enabled { loadAssignments() }
    }

    var totalTokens: Int64 { groups.reduce(0) { $0 + $1.tokens.total } }
    var threadCount: Int { Set(groups.flatMap { $0.threadTokens.keys }).count }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        defaults.set(value, forKey: "projectAnalyticsEnabled")
        cancel()
        if value {
            loadAssignments()
            refresh()
        } else {
            snapshot = nil
            groups = []
            sources = []
            capturedAt = nil
            assignments = [:]
            Task { await scanner.clear() }
        }
    }

    func setSource(_ provider: AnalyticsProvider, enabled value: Bool) {
        if provider == .codex {
            codexEnabled = value
            defaults.set(value, forKey: "analyticsCodexEnabled")
        } else {
            claudeEnabled = value
            defaults.set(value, forKey: "analyticsClaudeEnabled")
        }
        // Do not continue displaying usage from an excluded source.
        cancel()
        snapshot = nil
        groups = []
        sources = []
        capturedAt = nil
        if enabled { refresh() }
    }

    func refreshIfNeeded() {
        guard enabled, !refreshing else { return }
        if capturedAt == nil || Date().timeIntervalSince(capturedAt!) > 300 { refresh() }
    }

    func refresh() {
        guard enabled else { return }
        cancel()
        let id = UUID()
        requestID = id
        refreshing = true
        errorText = assignmentError
        let providers = Set(AnalyticsProvider.allCases.filter { $0 == .codex ? codexEnabled : claudeEnabled })
        let now = Date()
        let since = AnalyticsPeriod.month.start(at: now)
        let scanner = scanner
        let home = home
        refreshTask = Task { [weak self] in
            do {
                let result = try await scanner.scan(home: home, providers: providers, since: since, now: now)
                guard let self, !Task.isCancelled, self.enabled, self.requestID == id else { return }
                self.snapshot = result
                self.sources = result.sources
                self.capturedAt = result.capturedAt
                self.rebuildGroups()
                self.refreshing = false
                self.refreshTask = nil
            } catch is CancellationError { }
            catch {
                guard let self, self.requestID == id, self.enabled else { return }
                self.errorText = "Local logs could not be read. Please refresh again."
                self.refreshing = false
                self.refreshTask = nil
            }
        }
    }

    func assignment(for key: String) -> AnalyticsAssignment { assignments[key] ?? AnalyticsAssignment() }

    func assign(keys: Set<String>, projectName: String, topic: String) {
        guard enabled else { return }
        let value = AnalyticsAssignment(projectName: String(projectName.prefix(80)), topic: String(topic.prefix(80)))
        for key in keys { assignments[key] = value }
        guard assignmentsReadable else {
            errorText = assignmentError
            rebuildGroups()
            return
        }
        do {
            let directory = assignmentURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(assignments)
            try data.write(to: assignmentURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: assignmentURL.path)
            errorText = nil
            assignmentError = nil
        } catch {
            errorText = "The assignment could not be saved. It will last only until the next launch."
        }
        rebuildGroups()
    }

    func clearAssignments() {
        guard assignmentsReadable else { errorText = assignmentError; return }
        assignments = [:]
        do {
            if FileManager.default.fileExists(atPath: assignmentURL.path) {
                try Data("{}".utf8).write(to: assignmentURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: assignmentURL.path)
            }
            rebuildGroups()
            assignmentError = nil
            errorText = nil
        } catch { errorText = "Assignments could not be reset." }
    }

    private func cancel() {
        requestID = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        refreshing = false
        errorText = assignmentError
    }

    private func loadAssignments() {
        guard enabled else { return }
        assignmentError = nil
        assignmentsReadable = true
        guard FileManager.default.fileExists(atPath: assignmentURL.path) else { errorText = nil; return }
        do {
            assignments = try JSONDecoder().decode([String: AnalyticsAssignment].self, from: Data(contentsOf: assignmentURL))
        } catch {
            assignmentsReadable = false
            assignmentError = "Saved assignments could not be read. The file is unchanged."
        }
        errorText = assignmentError
    }

    private func rebuildGroups() {
        guard enabled, let snapshot else { groups = []; return }
        groups = snapshot.groups(grouping: grouping, since: period.start(at: Date()), until: Date(), assignments: assignments)
    }
}
