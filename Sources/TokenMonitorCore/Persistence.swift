import Foundation

public protocol SnapshotPersisting {
    func loadSnapshots() throws -> [ServiceKind: ServiceSnapshot]
    func saveSnapshots(_ snapshots: [ServiceKind: ServiceSnapshot]) throws
}

public final class FileSnapshotStore: SnapshotPersisting, @unchecked Sendable {
    private let fileManager: FileManager
    public let directoryURL: URL
    public let snapshotsURL: URL

    public init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let baseDirectory = directoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TokenMonitor", isDirectory: true)
        self.directoryURL = baseDirectory
        snapshotsURL = baseDirectory.appendingPathComponent("snapshots.json")
    }

    public func loadSnapshots() throws -> [ServiceKind: ServiceSnapshot] {
        guard fileManager.fileExists(atPath: snapshotsURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: snapshotsURL)
        let archive = try JSONDecoder.iso8601.decode(SnapshotArchive.self, from: data)
        return Dictionary(uniqueKeysWithValues: archive.snapshots.map { ($0.service, $0) })
    }

    public func saveSnapshots(_ snapshots: [ServiceKind: ServiceSnapshot]) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let archive = SnapshotArchive(snapshots: snapshots.values.sorted(by: { $0.service.rawValue < $1.service.rawValue }))
        let data = try JSONEncoder.prettyPrinted.encode(archive)
        try data.write(to: snapshotsURL, options: .atomic)
    }
}

private struct SnapshotArchive: Codable {
    let snapshots: [ServiceSnapshot]
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
