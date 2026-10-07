import Foundation
import Testing
@testable import TokenMonitorCore

struct AccountTests {
    @Test func newAccountNamesAvoidRenamedAccountCollisions() {
        let renamed = MonitoredAccount(id: UUID(), service: .claude, name: "Claude 2", isPrimary: true)
        #expect(MonitoredAccount.nextName(for: .claude, in: [renamed]) == "Claude")
        let primary = MonitoredAccount.primary(for: .claude)
        #expect(MonitoredAccount.nextName(for: .claude, in: [primary, renamed]) == "Claude 3")
        let lowercase = MonitoredAccount(id: UUID(), service: .claude, name: "claude 3", isPrimary: false)
        #expect(MonitoredAccount.nextName(for: .claude, in: [primary, renamed, lowercase]) == "Claude 4")
        #expect(MonitoredAccount.nextName(for: .chatGPT, in: [primary, renamed]) == "ChatGPT")
    }

    @Test func legacySnapshotBecomesPrimaryAccountWithoutChangingItsIdentity() throws {
        let snapshot = ServiceSnapshot(service: .claude, capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                       pageTitle: "Usage", url: "https://claude.ai/settings/usage", metrics: [])
        let accounts = AccountMigration.restoring([], legacySnapshots: [.claude: snapshot])
        #expect(accounts.count == ServiceKind.allCases.count)
        #expect(accounts.first(where: { $0.service == .claude })?.id == ServiceKind.claude.dataStoreIdentifier)
        #expect(accounts.first(where: { $0.service == .claude })?.snapshot == snapshot)
    }

    @Test func multipleAccountsRetainIndependentSnapshotsAndNames() throws {
        let secondID = UUID()
        let snapshot = ServiceSnapshot(service: .claude, capturedAt: .now,
                                       pageTitle: "Usage", url: "https://claude.ai/settings/usage", metrics: [])
        let saved = [MonitoredAccount(id: secondID, service: .claude,
                                     name: "Second Brain", isPrimary: false, snapshot: snapshot)]
        let accounts = AccountMigration.restoring(saved, legacySnapshots: [:])
        let state = DashboardState.initial(accounts: accounts)
        #expect(state.service(.claude).snapshot == nil)
        #expect(state.account(secondID)?.snapshot == snapshot)
        #expect(state.account(secondID)?.accountName == "Second Brain")

        var updated = state
        DashboardReducer.reduce(&updated, event: .account(secondID, .disconnected(message: "Connect account")))
        #expect(updated.account(secondID)?.snapshot == nil)
        #expect(updated.service(.claude).accountID == ServiceKind.claude.dataStoreIdentifier)
    }

    @Test func accountsPersistIndependentlyFromLegacySnapshotArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileAccountStore(directoryURL: directory)
        let snapshot = ServiceSnapshot(service: .claude, capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                       pageTitle: "Usage", url: "https://claude.ai/settings/usage", metrics: [])
        let account = MonitoredAccount(id: UUID(), service: .claude,
                                       name: "Second Brain", isPrimary: false, snapshot: snapshot)
        try store.saveAccounts([account])
        #expect(try store.loadAccounts() == [account])
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("snapshots.json").path))
    }
}
