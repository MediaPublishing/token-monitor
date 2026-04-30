import Foundation
import TokenMonitorCore

struct RefreshDebugRecord: Codable, Sendable {
    enum Outcome: String, Codable, Sendable {
        case success
        case parseFailure
        case authRequired
        case transportFailure
        case navigationBlocked
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
    private let decoder: JSONDecoder

    var isEnabled: Bool

    init(baseDirectory: URL, isEnabled: Bool = false, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.isEnabled = isEnabled
        directoryURL = baseDirectory.appendingPathComponent("Debug", isDirectory: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func record(_ debugRecord: RefreshDebugRecord) {
        guard isEnabled else {
            return
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(debugRecord.redacted)
            try data.write(to: latestRecordURL(for: debugRecord.service), options: .atomic)
        } catch {
            NSLog("Failed to write debug record: \(error.localizedDescription)")
        }
    }

    func latestRecords() -> [RefreshDebugRecord] {
        ServiceKind.allCases.compactMap { service in
            let fileURL = latestRecordURL(for: service)
            guard fileManager.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            return try? decoder.decode(RefreshDebugRecord.self, from: data)
        }
    }

    func writeReport(_ report: String) -> URL? {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let fileURL = directoryURL
                .appendingPathComponent("report-\(formatter.string(from: Date()))")
                .appendingPathExtension("txt")
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            NSLog("Failed to write debug report: \(error.localizedDescription)")
            return nil
        }
    }

    var directoryPath: String {
        directoryURL.path
    }

    private func latestRecordURL(for service: ServiceKind) -> URL {
        directoryURL
            .appendingPathComponent("\(service.rawValue)-latest")
            .appendingPathExtension("json")
    }
}
