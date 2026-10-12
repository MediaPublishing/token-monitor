import Foundation

public struct ChatGPTLoginNavigation: Sendable {
    public enum Action: Equatable, Sendable {
        case wait, loadUsage, complete
    }

    public static let connectionURL = URL(string: "https://chatgpt.com/")!
    private var didRequestUsage = false

    public init() {}

    public mutating func navigationStarted(at url: URL?) {
        guard let url else { return }
        let host = url.host()?.lowercased() ?? ""
        if host == "auth.openai.com" || host.hasSuffix(".auth.openai.com")
            || (host == "chatgpt.com" && (url.path == "/auth" || url.path.hasPrefix("/auth/"))) {
            didRequestUsage = false
        }
    }

    public mutating func action(for page: ServicePageExtract, hasAuthenticatedSession: Bool) -> Action {
        guard page.service == .chatGPT, let url = URL(string: page.url),
              url.scheme == "https", url.host()?.lowercased() == "chatgpt.com",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return .wait }

        // A usage URL alone can be an unauthenticated redirect or a loading shell.
        if let snapshot = try? ChatGPTUsageParser().parse(extract: page, now: Date()), !snapshot.metrics.isEmpty {
            return .complete
        }
        let isUsageRoute = url.path == ServiceKind.chatGPT.usageURL.path || url.path == "/settings/usage"
            || url.fragment?.lowercased() == "settings/usage"
        guard hasAuthenticatedSession, !didRequestUsage, !isUsageRoute,
              !page.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .wait }
        didRequestUsage = true
        return .loadUsage
    }
}
