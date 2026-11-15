import Foundation

public enum ClaudeUsageNavigation {
    // Readiness only, never proof of authentication or readable quotas.
    public static func isUsageURL(_ value: String) -> Bool {
        guard let url = URL(string: value), url.scheme?.lowercased() == "https",
              ["claude.ai", "www.claude.ai"].contains(url.host?.lowercased() ?? ""),
              url.port == nil || url.port == 443 else { return false }
        let trim = CharacterSet(charactersIn: "/")
        return url.path.trimmingCharacters(in: trim) == "settings/usage"
            || url.fragment?.trimmingCharacters(in: trim) == "settings/usage"
    }
}
