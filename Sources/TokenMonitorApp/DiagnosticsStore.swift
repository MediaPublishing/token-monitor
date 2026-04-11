import Foundation
import TokenMonitorCore

struct RefreshDebugRecord: Codable, Sendable {
    enum Outcome: String, Codable, Sendable {
        case success
        case parseFailure
        case authRequired
        case transportFailure
    }

    let timestamp: Date
    let service: ServiceKind
    let outcome: Outcome
    let pageTitle: String
    let url: String
    let bodyPreview: String
    let segments: [String]
    let message: String?

    var redacted: RefreshDebugRecord {
        RefreshDebugRecord(
            timestamp: timestamp,
            service: service,
            outcome: outcome,
            pageTitle: pageTitle,
            url: url,
            bodyPreview: Self.redact(bodyPreview),
            segments: segments.map(Self.redact),
            message: message.map(Self.redact)
        )
    }

    private static func redact(_ text: String) -> String {
        var sanitized = text
        let patterns = [
            #""accessToken"\s*:\s*"[^"]+""#,
            #""sessionToken"\s*:\s*"[^"]+""#,
            #""email"\s*:\s*"[^"]+""#,
            #"eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "[redacted]")
        }

        return sanitized
    }
}

@MainActor
final class DiagnosticsStore {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        directoryURL = baseDirectory.appendingPathComponent("Debug", isDirectory: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func record(_ debugRecord: RefreshDebugRecord) {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let fileURL = directoryURL
                .appendingPathComponent("\(debugRecord.service.rawValue)-latest")
                .appendingPathExtension("json")
            let data = try encoder.encode(debugRecord.redacted)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to write debug record: \(error.localizedDescription)")
        }
    }

    var directoryPath: String {
        directoryURL.path
    }
}
