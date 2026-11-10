import Foundation
import TokenMonitorCore

// Diagnostic hints only: presence does not prove authentication or valid usage.
// Never retain the source strings, even when recognizing a page fails.
struct RefreshPageDiagnostics: Codable, Equatable, Sendable {
    enum Page: String, Codable, Sendable {
        case blank, invalid, external, login, usage, otherProviderPage
    }
    enum Limit: String, Codable, CaseIterable, Sendable {
        case session, weekly, modelSpecific, monthly
    }
    struct Presence: Codable, Equatable, Sendable {
        let limit: Limit
        let heading: Bool
        let percentage: Bool
        let reset: Bool
    }
    let page: Page
    let hasReadableText: Bool
    let loginMarker: Bool
    let challengeMarker: Bool
    let limits: [Presence]

    init(extract: ServicePageExtract) {
        if extract.url == "about:blank" || extract.url.isEmpty {
            page = .blank
        } else if let url = URL(string: extract.url), let host = url.host?.lowercased(),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            let hosts: [String]
            switch extract.service {
            case .claude: hosts = ["claude.ai", "www.claude.ai"]
            case .chatGPT: hosts = ["chatgpt.com", "www.chatgpt.com", "auth.openai.com", "auth0.openai.com"]
            case .openCodeGo: hosts = ["opencode.ai", "www.opencode.ai"]
            }
            let path = url.path.lowercased()
            if !hosts.contains(host) { page = .external }
            else if path.contains("/login") || path.contains("/auth") { page = .login }
            else if path.hasSuffix("/settings/usage") || (extract.service == .openCodeGo && path.hasSuffix("/go")) { page = .usage }
            else { page = .otherProviderPage }
        } else { page = .invalid }

        let sources = [extract.bodyText] + extract.segments
        let text = sources.joined(separator: "\n").lowercased()
        hasReadableText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        loginMarker = ["log in", "sign in", "continue with google", "anmelden", "melde dich an", "mit google fortfahren"]
            .contains(where: text.contains)
        challengeMarker = ["verify you're human", "verify you are human", "verification failure", "checking your browser"]
            .contains(where: text.contains)

        let labels: [(Limit, [String])]
        switch extract.service {
        case .claude:
            labels = [(.session, ["current session", "aktuelle sitzung", "sitzung"]),
                      (.weekly, ["all models", "alle modelle", "this week", "diese woche"]),
                      (.modelSpecific, ["fable", "fable this week", "fable diese woche", "sonnet only", "nur sonnet", "claude design"])]
        case .chatGPT:
            labels = [(.session, ["5 hour usage limit", "5-hour usage limit", "5-hour limit", "5-stunden-nutzungslimit"]),
                      (.weekly, ["weekly usage limit", "weekly limit", "wöchentliches nutzungslimit", "wöchentliches limit"])]
        case .openCodeGo:
            labels = [(.session, ["rolling usage", "5-hour usage"]),
                      (.weekly, ["weekly usage"]), (.monthly, ["monthly usage"])]
        }
        let allLabels = labels.flatMap(\.1)
        let linesBySource = sources.map { source in
            source.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        }
        limits = labels.map { limit, headings in
            var found = false, percent = false, reset = false
            for lines in linesBySource {
                for index in lines.indices where headings.contains(lines[index]) {
                    found = true
                    for line in lines[(index + 1)..<min(index + 9, lines.count)] {
                        if allLabels.contains(line) { break }
                        if line.range(of: #"\d+(?:[.,]\d+)?\s*%"#, options: .regularExpression) != nil { percent = true }
                        if ["reset", "zurückgesetzt", "zurücksetzung", "setzt zurück"].contains(where: line.contains) { reset = true }
                    }
                }
            }
            return Presence(limit: limit, heading: found, percentage: percent, reset: reset)
        }
    }

    var reportLines: [String] {
        ["- Page category: \(page.rawValue)", "- Readable text: \(hasReadableText)",
         "- Login marker: \(loginMarker)", "- Challenge marker: \(challengeMarker)"]
        + limits.map { "- \($0.limit.rawValue): heading=\($0.heading), percentage=\($0.percentage), reset=\($0.reset)" }
    }
}

struct RefreshDiagnosticAccount {
    let id: UUID
    let service: ServiceKind
    let status: ServiceConnectionStatus
}

enum RefreshDiagnosticsReport {
    static func render(version: String, build: String, os: OperatingSystemVersion,
                       enabled: Bool, accounts: [RefreshDiagnosticAccount], records: [RefreshDebugRecord]) -> String {
        func number(_ value: String) -> String {
            value.count <= 32 && value.range(of: #"^[0-9]+(?:\.[0-9]+)*$"#, options: .regularExpression) != nil ? value : "unknown"
        }
        var aliases: [UUID: String] = [:]
        var counts: [ServiceKind: Int] = [:]
        func alias(_ id: UUID?, service: ServiceKind) -> String {
            guard let id else { return "\(service.displayName) legacy account (unattributable)" }
            if let existing = aliases[id] { return existing }
            counts[service, default: 0] += 1
            let name = "\(service.displayName) account \(counts[service, default: 0])"
            aliases[id] = name
            return name
        }
        var lines = ["# Token Monitor Debug Report", "", "Created: \(ISO8601DateFormatter().string(from: Date()))",
                     "App version: \(number(version)) (\(number(build)))",
                     "macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                     "Debug mode enabled: \(enabled)", "",
                     "Privacy: no page text, chat titles, URLs, account names or account IDs included.",
                     "Recognition markers are hints, not proof of authentication or valid usage.", "", "## Current status"]
        for account in accounts {
            lines.append("- \(alias(account.id, service: account.service)): \(account.status.rawValue)")
        }
        lines += ["", "## Latest refreshes and retained failures", "Retained failures may predate current status; compare timestamps."]
        if records.isEmpty { lines.append("No records. Enable debug mode and refresh the affected account first.") }
        for source in records {
            let record = source.redacted
            lines += ["", "### \(alias(record.accountID, service: record.service))",
                      "- Timestamp: \(ISO8601DateFormatter().string(from: record.timestamp))",
                      "- Outcome: \(record.outcome.rawValue)"]
            lines += record.pageDiagnostics?.reportLines ?? ["- Page diagnostics unavailable"]
        }
        lines += ["", "Saved locally. Review before sharing. Nothing is uploaded automatically.",
                  "Use Save Performance Report separately for CPU/resource problems."]
        return lines.joined(separator: "\n")
    }
}
