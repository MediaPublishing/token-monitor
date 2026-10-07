import Foundation

public struct MonitoredAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let service: ServiceKind
    public var name: String
    public let isPrimary: Bool
    public var snapshot: ServiceSnapshot?

    public init(id: UUID, service: ServiceKind, name: String, isPrimary: Bool, snapshot: ServiceSnapshot? = nil) {
        self.id = id
        self.service = service
        self.name = name
        self.isPrimary = isPrimary
        self.snapshot = snapshot
    }

    public static func primary(for service: ServiceKind) -> MonitoredAccount {
        MonitoredAccount(id: service.dataStoreIdentifier, service: service,
                         name: service.displayName, isPrimary: true)
    }

    public static func nextName(for service: ServiceKind, in accounts: [MonitoredAccount]) -> String {
        let names = Set(accounts.filter { $0.service == service }.map { $0.name.lowercased() })
        let base = service.displayName
        if !names.contains(base.lowercased()) { return base }
        var suffix = 2
        while names.contains("\(base) \(suffix)".lowercased()) { suffix += 1 }
        return "\(base) \(suffix)"
    }
}

public protocol AccountPersisting {
    func loadAccounts() throws -> [MonitoredAccount]
    func saveAccounts(_ accounts: [MonitoredAccount]) throws
}

public final class FileAccountStore: AccountPersisting, @unchecked Sendable {
    public let accountsURL: URL
    private let fileManager: FileManager

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = directoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TokenMonitor", isDirectory: true)
        accountsURL = directory.appendingPathComponent("accounts.json")
    }

    public func loadAccounts() throws -> [MonitoredAccount] {
        guard fileManager.fileExists(atPath: accountsURL.path) else { return [] }
        let data = try Data(contentsOf: accountsURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MonitoredAccount].self, from: data)
    }

    public func saveAccounts(_ accounts: [MonitoredAccount]) throws {
        try fileManager.createDirectory(at: accountsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(accounts).write(to: accountsURL, options: .atomic)
    }
}

public enum AccountMigration {
    public static func restoring(_ saved: [MonitoredAccount], legacySnapshots: [ServiceKind: ServiceSnapshot]) -> [MonitoredAccount] {
        var result = ServiceKind.allCases.map { service -> MonitoredAccount in
            var account = saved.first(where: { $0.id == service.dataStoreIdentifier && $0.service == service })
                ?? .primary(for: service)
            account.snapshot = legacySnapshots[service] ?? account.snapshot
            return account
        }
        var seen = Set(result.map(\.id))
        for account in saved where !account.isPrimary && !seen.contains(account.id) {
            result.append(account)
            seen.insert(account.id)
        }
        return result
    }
}
