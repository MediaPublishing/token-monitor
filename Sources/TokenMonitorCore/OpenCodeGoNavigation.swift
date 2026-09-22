import Foundation

public enum OpenCodeGoNavigation {
    public static let accountURL = URL(string: "https://opencode.ai/auth")!
    public static let consoleUsageURL = URL(string: "https://opencode.ai/console/go")!

    public static func workspaceURL(from value: String?) -> URL? {
        guard let value, var url = URLComponents(string: value),
              url.scheme == "https", url.host?.lowercased() == "opencode.ai",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              url.path.range(of: #"^/(?:(?:[a-z]{2}(?:-[A-Za-z]{2,4})?/)?workspace/[A-Za-z0-9_-]+|console/(?:org_|wrk_)[A-Za-z0-9_-]+)/go/?$"#,
                             options: .regularExpression) != nil else { return nil }
        url.query = nil
        url.fragment = nil
        return url.url
    }

    public static func refreshURL(lastKnownURL: String?) -> URL {
        workspaceURL(from: lastKnownURL) ?? accountURL
    }

    public static func isConsoleURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return url.scheme == "https" && url.host == "opencode.ai" && url.path.hasPrefix("/console/")
    }
}

public extension ServicePageExtract {
    var openCodeGoWorkspaceURL: URL? {
        guard service == .openCodeGo else { return nil }
        return OpenCodeGoNavigation.workspaceURL(from: url)
            ?? links.compactMap { OpenCodeGoNavigation.workspaceURL(from: $0) }.first
    }
}
