import Foundation

public struct ClaudeUsageResponse: Codable, Equatable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case available, notReported, unauthorized, forbidden, challenge, rateLimited
        case ambiguousWorkspace, noWorkspace, invalidResponse, networkFailure, timedOut, untrustedOrigin
    }
    public enum Stage: String, Codable, Sendable { case origin, organizations, usage }
    public enum Scope: String, Codable, Sendable {
        case session, weekly, sonnet, opus, fable
        var metric: (String, String) {
            switch self {
            case .session: ("current-session", "Current session")
            case .weekly: ("weekly-all-models", "All models")
            case .sonnet: ("weekly-sonnet", "Sonnet only")
            case .opus: ("weekly-opus", "Opus")
            case .fable: ("weekly-fable", "Fable")
            }
        }
    }
    public struct Window: Codable, Equatable, Sendable {
        public let scope: Scope
        public let used: Double
        public let resetsAt: String?
    }
    public let outcome: Outcome
    public let stage: Stage
    public let httpStatus: Int?
    public let confirmedEmpty: Bool?
    public let windows: [Window]?

    public func snapshot(now: Date) throws -> ServiceSnapshot {
        guard stage == .usage, httpStatus == 200 else { throw invalidLayout }
        let windows = windows ?? []
        if outcome == .notReported, confirmedEmpty == true, windows.isEmpty {
            return ServiceSnapshot(service: .claude, capturedAt: now, pageTitle: "Usage",
                url: ServiceKind.claude.usageURL.absoluteString, metrics: [], quotaAvailability: .notReported)
        }
        guard outcome == .available, !windows.isEmpty, windows.count <= 5,
              Set(windows.map(\.scope)).count == windows.count else { throw invalidLayout }
        let metrics = try windows.map { window -> UsageMetric in
            guard window.used.isFinite, (0...100).contains(window.used) else { throw invalidLayout }
            let remaining = 100 - window.used
            let subtitle: String?
            if let raw = window.resetsAt {
                guard raw.count <= 40, let date = Self.resetDate(raw) else { throw invalidLayout }
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "EEE HH:mm"
                subtitle = "Reset: " + formatter.string(from: date)
            } else {
                subtitle = window.scope == .session && window.used == 0
                    ? "Starts with your first message" : "Reset unavailable"
            }
            return UsageMetric(key: window.scope.metric.0, title: window.scope.metric.1,
                valueText: "\(Int(remaining.rounded()))% remaining", subtitle: subtitle,
                progress: remaining / 100, style: .progress)
        }
        return ServiceSnapshot(service: .claude, capturedAt: now, pageTitle: "Usage",
            url: ServiceKind.claude.usageURL.absoluteString, metrics: metrics)
    }

    public var failureMessage: String {
        switch outcome {
        case .unauthorized: "Claude login required"
        case .forbidden: "Claude usage access denied (HTTP 403)"
        case .challenge: "Claude requires browser verification"
        case .rateLimited: "Claude usage temporarily rate-limited (HTTP 429)"
        case .ambiguousWorkspace: "Claude workspace could not be selected safely"
        case .noWorkspace: "No Claude chat workspace was reported"
        case .timedOut: "Claude usage request timed out"
        case .networkFailure: "Claude usage request failed"
        case .untrustedOrigin: "Claude usage page did not reach a trusted origin"
        default: "Claude usage response could not be read"
        }
    }

    private var invalidLayout: UsageParseError { .unsupportedLayout("Claude usage response could not be read") }
    private static func resetDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}
