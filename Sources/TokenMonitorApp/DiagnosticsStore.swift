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
            let data = try encoder.encode(debugRecord)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to write debug record: \(error.localizedDescription)")
        }
    }

    var directoryPath: String {
        directoryURL.path
    }
}
