import Foundation
import TokenMonitorCore

struct RefreshDebugRecord: Codable, Equatable, Sendable {
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
    var accountID: UUID? = nil
    var pageDiagnostics: RefreshPageDiagnostics? = nil

    var redacted: RefreshDebugRecord {
        RefreshDebugRecord(
            timestamp: timestamp,
            service: service,
            outcome: outcome,
            pageTitle: "",
            url: "",
            bodyPreview: "",
            segments: [],
            message: nil,
            accountID: accountID,
            pageDiagnostics: pageDiagnostics ?? RefreshPageDiagnostics(extract: ServicePageExtract(
                service: service, pageTitle: "", url: url, bodyText: bodyPreview, segments: segments))
        )
    }

}

@MainActor
final class DiagnosticsStore {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    let performance: PerformanceRecorder
    var isEnabled: Bool { didSet { performance.setEnabled(isEnabled) } }

    init(baseDirectory: URL, isEnabled: Bool = false, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.isEnabled = isEnabled
        directoryURL = baseDirectory.appendingPathComponent("Debug", isDirectory: true)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        #if MAS_BUILD
        let allowSampling = false
        #else
        let allowSampling = true
        #endif
        performance = PerformanceRecorder(directory: directoryURL.appendingPathComponent("Performance", isDirectory: true),
                                          version: "\(version) (\(build))", stackSamplingAllowed: allowSampling)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        performance.setEnabled(isEnabled)
    }

    func record(_ debugRecord: RefreshDebugRecord) {
        guard isEnabled else {
            return
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
            let data = try encoder.encode(debugRecord.redacted)
            var destinations = [recordURL(for: debugRecord, suffix: "latest")]
            if debugRecord.outcome != .success && debugRecord.outcome != .navigationBlocked {
                destinations.append(recordURL(for: debugRecord, suffix: "last-failure"))
            }
            for url in destinations {
                try data.write(to: url, options: .atomic)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            }
        } catch {
            NSLog("Failed to write debug record: \(error.localizedDescription)")
        }
    }

    func latestRecords() -> [RefreshDebugRecord] {
        let files = (try? fileManager.contentsOfDirectory(at: directoryURL,
            includingPropertiesForKeys: nil)) ?? []
        var records: [RefreshDebugRecord] = []
        for file in files where file.lastPathComponent.hasSuffix("-latest.json")
            || file.lastPathComponent.hasSuffix("-last-failure.json") {
            guard let data = try? Data(contentsOf: file),
                  let record = try? decoder.decode(RefreshDebugRecord.self, from: data),
                  file.lastPathComponent == recordURL(for: record, suffix: "latest").lastPathComponent
                    || file.lastPathComponent == recordURL(for: record, suffix: "last-failure").lastPathComponent else { continue }
            let safe = record.redacted
            if !records.contains(safe) { records.append(safe) }
        }
        return records.sorted { $0.timestamp < $1.timestamp }
    }

    func writeReport(_ report: String) -> URL? {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let fileURL = directoryURL
                .appendingPathComponent("report-\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(8))")
                .appendingPathExtension("txt")
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return fileURL
        } catch {
            NSLog("Failed to write debug report: \(error.localizedDescription)")
            return nil
        }
    }

    var directoryPath: String {
        directoryURL.path
    }

    func writePerformanceReport() -> URL? {
        let url = directoryURL.appendingPathComponent("performance-report.txt")
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
            try performance.reportText.write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url
        } catch { return nil }
    }

    private func recordURL(for record: RefreshDebugRecord, suffix: String) -> URL {
        let accountSuffix = record.accountID.map { "-\($0.uuidString)" } ?? ""
        return directoryURL
            .appendingPathComponent("\(record.service.rawValue)\(accountSuffix)-\(suffix)")
            .appendingPathExtension("json")
    }
}
