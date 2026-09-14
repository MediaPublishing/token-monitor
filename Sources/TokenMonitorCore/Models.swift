import Foundation

public enum ServiceKind: String, CaseIterable, Codable, Sendable {
    case claude
    case chatGPT = "chatgpt"
    case openCodeGo = "opencode-go"

    public var displayOrder: Int {
        switch self {
        case .claude:
            return 0
        case .chatGPT:
            return 1
        case .openCodeGo:
            return 2
        }
    }

    public var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .chatGPT:
            return "ChatGPT"
        case .openCodeGo:
            return "OpenCode Go"
        }
    }

    public var usageURL: URL {
        switch self {
        case .claude:
            return URL(string: "https://claude.ai/settings/usage")!
        case .chatGPT:
            return URL(string: "https://chatgpt.com/codex/cloud/settings/usage")!
        case .openCodeGo:
            return URL(string: "https://opencode.ai/go")!
        }
    }

    public var loginRequiredMessage: String {
        switch self {
        case .claude:
            return "Claude login required"
        case .chatGPT:
            return "ChatGPT login required"
        case .openCodeGo:
            return "OpenCode Go login required"
        }
    }

    public var dataStoreIdentifier: UUID {
        switch self {
        case .claude:
            return UUID(uuidString: "E54F2F77-0C8B-4A14-A177-74DF3065A38F")!
        case .chatGPT:
            return UUID(uuidString: "2AA8D9AD-9434-4CE0-8329-F51C5FA36627")!
        case .openCodeGo:
            return UUID(uuidString: "C4BBE7F3-4F4D-4CA4-97D9-B28ECF4316A2")!
        }
    }
}

public struct ServicePageExtract: Codable, Equatable, Sendable {
    public let service: ServiceKind
    public let pageTitle: String
    public let url: String
    public let bodyText: String
    public let segments: [String]
    public let links: [String]
    public let bankedResetText: String?
    public let pageTimeZone: String?

    public init(
        service: ServiceKind,
        pageTitle: String,
        url: String,
        bodyText: String,
        segments: [String],
        links: [String] = [],
        bankedResetText: String? = nil,
        pageTimeZone: String? = nil
    ) {
        self.service = service
        self.pageTitle = pageTitle
        self.url = url
        self.bodyText = bodyText
        self.segments = segments
        self.links = links
        self.bankedResetText = bankedResetText
        self.pageTimeZone = pageTimeZone
    }

    private enum CodingKeys: String, CodingKey {
        case service
        case pageTitle
        case url
        case bodyText
        case segments
        case links
        case bankedResetText
        case pageTimeZone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        service = try container.decode(ServiceKind.self, forKey: .service)
        pageTitle = try container.decode(String.self, forKey: .pageTitle)
        url = try container.decode(String.self, forKey: .url)
        bodyText = try container.decode(String.self, forKey: .bodyText)
        segments = try container.decode([String].self, forKey: .segments)
        links = try container.decodeIfPresent([String].self, forKey: .links) ?? []
        bankedResetText = try container.decodeIfPresent(String.self, forKey: .bankedResetText)
        pageTimeZone = try container.decodeIfPresent(String.self, forKey: .pageTimeZone)
    }
}

public enum UsageMetricStyle: String, Codable, Equatable, Sendable {
    case progress
    case stat
}

public struct UsageMetric: Codable, Equatable, Identifiable, Sendable {
    public let key: String
    public let title: String
    public let valueText: String
    public let subtitle: String?
    public let progress: Double?
    public let style: UsageMetricStyle

    public init(key: String, title: String, valueText: String, subtitle: String?, progress: Double?, style: UsageMetricStyle) {
        self.key = key
        self.title = title
        self.valueText = valueText
        self.subtitle = subtitle
        self.progress = progress
        self.style = style
    }

    public var id: String { key }

    public var displaySubtitle: String? {
        guard let subtitle else {
            return nil
        }
        return compactResetText(subtitle)
    }

    private func compactResetText(_ text: String) -> String {
        let withoutLongYear = text.replacingOccurrences(
            of: #",\s*\d{4}"#,
            with: "",
            options: .regularExpression
        )
        let shortenedPrefix = withoutLongYear.replacingOccurrences(
            of: #"^Resets\b"#,
            with: "Reset",
            options: [.regularExpression, .caseInsensitive]
        )

        return Self.convertingMeridiemTimesToTwentyFourHour(shortenedPrefix)
    }

    private static func convertingMeridiemTimesToTwentyFourHour(_ text: String) -> String {
        let pattern = #"\b(\d{1,2}):(\d{2})\s*([AP]M)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = expression.matches(in: text, options: [], range: range).reversed()
        var result = text

        for match in matches {
            guard
                let fullRange = Range(match.range(at: 0), in: result),
                let hourRange = Range(match.range(at: 1), in: result),
                let minuteRange = Range(match.range(at: 2), in: result),
                let meridiemRange = Range(match.range(at: 3), in: result),
                let hour = Int(result[hourRange])
            else {
                continue
            }

            let minute = result[minuteRange]
            let meridiem = result[meridiemRange].uppercased()
            let convertedHour: Int
            if meridiem == "AM" {
                convertedHour = hour == 12 ? 0 : hour
            } else {
                convertedHour = hour == 12 ? 12 : hour + 12
            }

            result.replaceSubrange(fullRange, with: String(format: "%02d:%@", convertedHour, String(minute)))
        }

        return result
    }
}

public struct ServiceSnapshot: Codable, Equatable, Sendable {
    public let service: ServiceKind
    public let capturedAt: Date
    public let pageTitle: String
    public let url: String
    public let metrics: [UsageMetric]
    public var bankedResets: BankedResetInventory?

    public init(service: ServiceKind, capturedAt: Date, pageTitle: String, url: String, metrics: [UsageMetric], bankedResets: BankedResetInventory? = nil) {
        self.service = service
        self.capturedAt = capturedAt
        self.pageTitle = pageTitle
        self.url = url
        self.metrics = metrics
        self.bankedResets = bankedResets
    }

    public func metric(for key: String) -> UsageMetric? {
        metrics.first(where: { $0.key == key })
    }

    public var statusMenuTotalScore: Double? {
        switch service {
        case .chatGPT:
            return remainingScore(for: "weekly-limit") ?? remainingScore(for: "spark-weekly-limit") ?? capacityScore
        case .claude:
            return remainingScore(for: "weekly-all-models") ?? capacityScore
        case .openCodeGo:
            return remainingScore(for: "weekly-usage") ?? capacityScore
        }
    }

    public var statusMenuSessionScore: Double? {
        switch service {
        case .chatGPT:
            return remainingScore(for: "five-hour-limit") ?? remainingScore(for: "spark-five-hour-limit") ?? capacityScore
        case .claude:
            return remainingScore(for: "current-session") ?? capacityScore
        case .openCodeGo:
            return remainingScore(for: "rolling-usage") ?? capacityScore
        }
    }

    public var capacityScore: Double? {
        let relevantKeys: [String]
        switch service {
        case .chatGPT:
            relevantKeys = ["five-hour-limit", "weekly-limit", "spark-five-hour-limit", "spark-weekly-limit"]
        case .claude:
            relevantKeys = ["current-session", "weekly-all-models", "weekly-sonnet", "claude-design"]
        case .openCodeGo:
            relevantKeys = ["rolling-usage", "weekly-usage", "monthly-usage"]
        }

        let scores = relevantKeys.compactMap { key -> Double? in
            guard let metric = metric(for: key), let progress = metric.progress else {
                return nil
            }

            if metric.valueText.localizedCaseInsensitiveContains("remaining") {
                return progress
            }

            if metric.valueText.localizedCaseInsensitiveContains("used") {
                return max(0, 1 - progress)
            }

            return progress
        }

        guard !scores.isEmpty else {
            return nil
        }

        return scores.min()
    }

    private func remainingScore(for key: String) -> Double? {
        guard let metric = metric(for: key), let progress = metric.progress else {
            return nil
        }

        if metric.valueText.localizedCaseInsensitiveContains("remaining") {
            return progress
        }

        if metric.valueText.localizedCaseInsensitiveContains("used") {
            return max(0, 1 - progress)
        }

        return progress
    }
}

public enum UsageParseError: Error, Equatable, Sendable {
    case authRequired(String)
    case unsupportedLayout(String)
}

public enum RefreshTrigger: String, Codable, Equatable, Sendable {
    case launch
    case popover
    case manual
    case background
    case login
}

public enum RefreshState: Equatable, Sendable {
    case idle
    case refreshing(trigger: RefreshTrigger)
    case success(lastSuccess: Date)
    case stale(lastSuccess: Date, message: String)
    case authRequired(message: String)
    case failed(message: String)
}

public enum ServiceConnectionStatus: String, Equatable, Sendable {
    case healthy
    case refreshing
    case stale
    case authRequired
    case error
}

public struct ServiceStatus: Equatable, Sendable {
    public let service: ServiceKind
    public var snapshot: ServiceSnapshot?
    public var refreshState: RefreshState

    public init(service: ServiceKind, snapshot: ServiceSnapshot?, refreshState: RefreshState) {
        self.service = service
        self.snapshot = snapshot
        self.refreshState = refreshState
    }

    public var connectionStatus: ServiceConnectionStatus {
        switch refreshState {
        case .success:
            return .healthy
        case .refreshing:
            return .refreshing
        case .stale:
            return .stale
        case .authRequired:
            return .authRequired
        case .failed, .idle:
            return snapshot == nil ? .error : .stale
        }
    }

    public var lastSuccessfulRefresh: Date? {
        switch refreshState {
        case let .success(lastSuccess), let .stale(lastSuccess, _):
            return lastSuccess
        case .refreshing, .authRequired, .failed, .idle:
            return snapshot?.capturedAt
        }
    }

    // Call only for enabled providers. A missing snapshot does not imply that
    // an opted-in OpenCode provider has lost its persistent browser session.
    public func shouldSkipAutomaticRefresh(trigger: RefreshTrigger) -> Bool {
        switch trigger {
        case .launch, .background:
            if trigger == .launch && service == .openCodeGo {
                return false
            }
            if case .authRequired = refreshState, snapshot == nil {
                return true
            }
            if case let .stale(_, message) = refreshState,
               message.localizedCaseInsensitiveContains("login required") {
                return true
            }
            return false
        case .manual, .popover, .login:
            return false
        }
    }
}
