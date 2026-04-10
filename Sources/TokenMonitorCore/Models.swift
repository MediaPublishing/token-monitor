import Foundation

public enum ServiceKind: String, CaseIterable, Codable, Sendable {
    case claude
    case chatGPT = "chatgpt"

    public var displayOrder: Int {
        switch self {
        case .claude:
            return 0
        case .chatGPT:
            return 1
        }
    }

    public var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .chatGPT:
            return "ChatGPT"
        }
    }

    public var usageURL: URL {
        switch self {
        case .claude:
            return URL(string: "https://claude.ai/settings/usage")!
        case .chatGPT:
            return URL(string: "https://chatgpt.com/codex/cloud/settings/usage")!
        }
    }

    public var loginRequiredMessage: String {
        switch self {
        case .claude:
            return "Claude login required"
        case .chatGPT:
            return "ChatGPT login required"
        }
    }

    public var dataStoreIdentifier: UUID {
        switch self {
        case .claude:
            return UUID(uuidString: "E54F2F77-0C8B-4A14-A177-74DF3065A38F")!
        case .chatGPT:
            return UUID(uuidString: "2AA8D9AD-9434-4CE0-8329-F51C5FA36627")!
        }
    }
}

public struct ServicePageExtract: Codable, Equatable, Sendable {
    public let service: ServiceKind
    public let pageTitle: String
    public let url: String
    public let bodyText: String
    public let segments: [String]

    public init(service: ServiceKind, pageTitle: String, url: String, bodyText: String, segments: [String]) {
        self.service = service
        self.pageTitle = pageTitle
        self.url = url
        self.bodyText = bodyText
        self.segments = segments
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
}

public struct ServiceSnapshot: Codable, Equatable, Sendable {
    public let service: ServiceKind
    public let capturedAt: Date
    public let pageTitle: String
    public let url: String
    public let metrics: [UsageMetric]

    public init(service: ServiceKind, capturedAt: Date, pageTitle: String, url: String, metrics: [UsageMetric]) {
        self.service = service
        self.capturedAt = capturedAt
        self.pageTitle = pageTitle
        self.url = url
        self.metrics = metrics
    }

    public func metric(for key: String) -> UsageMetric? {
        metrics.first(where: { $0.key == key })
    }

    public var capacityScore: Double? {
        let relevantKeys: [String]
        switch service {
        case .chatGPT:
            relevantKeys = ["five-hour-limit", "weekly-limit", "spark-five-hour-limit", "spark-weekly-limit"]
        case .claude:
            relevantKeys = ["current-session", "weekly-all-models", "weekly-sonnet"]
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
        case .success, .refreshing:
            return .healthy
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
}
