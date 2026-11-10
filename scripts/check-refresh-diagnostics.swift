import Foundation
import TokenMonitorCore

@main
struct RefreshDiagnosticsProof {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticsStore(baseDirectory: directory, isEnabled: true)
        let privateRecord = RefreshDebugRecord(timestamp: Date(timeIntervalSince1970: 0), service: .claude,
            outcome: .parseFailure, pageTitle: "PrivateClientChat", url: "https://claude.ai/settings/usage?token=SecretQuery#PrivateFragment",
            bodyPreview: "PrivateSidebarChat\nAll models\nResets Fri 12:00\n41% used",
            segments: ["PrivateProjectChat"], message: "SecretErrorText")
        store.record(privateRecord)
        let storedPrivacyData = try String(contentsOf: directory.appendingPathComponent("Debug/claude-latest.json"), encoding: .utf8)
        guard !["PrivateClientChat", "SecretQuery", "PrivateFragment", "PrivateSidebarChat", "PrivateProjectChat", "SecretErrorText"]
            .contains(where: storedPrivacyData.contains) else {
            print("FAIL: refresh diagnostics store private page/sidebar/URL/error content")
            store.isEnabled = false
            exit(1)
        }
        print("PASS: new records omit private page, sidebar, URL and error content")
        let facts = store.latestRecords().first!.pageDiagnostics!
        precondition(facts.page == .usage)
        precondition(facts.limits.contains { $0.limit == .weekly && $0.heading && $0.percentage && $0.reset })
        precondition(facts.limits.contains { $0.limit == .session && !$0.heading })
        print("PASS: bounded technical recognition facts remain useful without raw text")

        let legacyDirectory = directory.appendingPathComponent("legacy")
        let legacyStore = DiagnosticsStore(baseDirectory: legacyDirectory)
        let legacyEncoder = JSONEncoder()
        legacyEncoder.dateEncodingStrategy = .iso8601
        let legacyURL = legacyDirectory.appendingPathComponent("Debug/claude-latest.json")
        try legacyEncoder.encode(privateRecord).write(to: legacyURL)
        let legacySafe = legacyStore.latestRecords()
        precondition(legacySafe.count == 1 && legacySafe[0].bodyPreview.isEmpty && legacySafe[0].url.isEmpty)
        precondition(legacySafe[0].pageDiagnostics?.page == .usage)
        // Reading/exporting must not silently rewrite or delete original legacy files.
        let unchangedLegacy = try String(contentsOf: legacyURL, encoding: .utf8)
        precondition(unchangedLegacy.contains("PrivateSidebarChat"))

        let exportID = UUID()
        var rawForExport = privateRecord
        rawForExport.accountID = exportID
        let exported = RefreshDiagnosticsReport.render(version: "1.0.53", build: "62",
            os: OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 2), enabled: false,
            accounts: [RefreshDiagnosticAccount(id: exportID, service: .claude, status: .stale)],
            records: [rawForExport] + legacySafe)
        for canary in ["PrivateClientChat", "SecretQuery", "PrivateFragment", "PrivateSidebarChat", "PrivateProjectChat", "SecretErrorText", exportID.uuidString, "https://"] {
            precondition(!exported.contains(canary))
        }
        precondition(exported.contains("Claude account 1") && exported.contains("heading=true, percentage=true, reset=true"))
        let reportURL = legacyStore.writeReport(exported)!
        let reportAttributes = try FileManager.default.attributesOfItem(atPath: reportURL.path)
        precondition((reportAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let savedReport = try String(contentsOf: reportURL, encoding: .utf8)
        precondition(savedReport == exported)
        print("PASS: legacy read and final exported file omit private content and account IDs; originals untouched")
        let failure = RefreshDebugRecord(timestamp: Date(timeIntervalSince1970: 1), service: .claude,
            outcome: .parseFailure, pageTitle: "Usage", url: "https://claude.ai/settings/usage",
            bodyPreview: "Unrecognized layout", segments: [], message: "parse failure")
        let success = RefreshDebugRecord(timestamp: Date(timeIntervalSince1970: 2), service: .claude,
            outcome: .success, pageTitle: "Usage", url: "https://claude.ai/settings/usage",
            bodyPreview: "This week", segments: [], message: nil)
        store.record(failure)
        store.record(success)
        guard store.latestRecords().contains(where: { $0.outcome == .parseFailure }) else {
            print("FAIL: successful refresh erased the preceding parse failure")
            store.isEnabled = false
            exit(1)
        }
        store.isEnabled = false
        print("PASS: a successful refresh preserves the preceding failure")

        let accountDirectory = directory.appendingPathComponent("accounts")
        let accountStore = DiagnosticsStore(baseDirectory: accountDirectory, isEnabled: true)
        defer { accountStore.isEnabled = false }
        let firstAccount = UUID()
        let secondAccount = UUID()
        var firstFailure = failure
        firstFailure.accountID = firstAccount
        var secondSuccess = success
        secondSuccess.accountID = secondAccount
        accountStore.record(firstFailure)
        accountStore.record(secondSuccess)
        let separate = accountStore.latestRecords()
        precondition(separate.count == 2)
        precondition(separate.contains { $0.accountID == firstAccount && $0.outcome == .parseFailure })
        precondition(separate.contains { $0.accountID == secondAccount && $0.outcome == .success })
        print("PASS: successful second Claude account cannot erase the first account's failure")

        var firstRecovery = success
        firstRecovery.accountID = firstAccount
        accountStore.record(firstRecovery)
        precondition(accountStore.latestRecords().count == 3)
        let reloaded = DiagnosticsStore(baseDirectory: accountDirectory)
        precondition(reloaded.latestRecords().count == 3)
        precondition(reloaded.latestRecords().contains { $0.accountID == firstAccount && $0.outcome == .parseFailure })
        print("PASS: last failure survives account recovery and store restart")

        let nextFailure = RefreshDebugRecord(timestamp: Date(timeIntervalSince1970: 3), service: .claude,
            outcome: .authRequired, pageTitle: "Login", url: "https://claude.ai/login",
            bodyPreview: "{\"accessToken\":\"synthetic-secret\"}", segments: ["{\"email\":\"example@test.invalid\"}"],
            message: "sign in", accountID: firstAccount)
        accountStore.record(nextFailure)
        precondition(accountStore.latestRecords().count == 2)
        precondition(!accountStore.latestRecords().contains { $0.outcome == .parseFailure })
        let debugDirectory = accountDirectory.appendingPathComponent("Debug")
        let files = try FileManager.default.contentsOfDirectory(at: debugDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        precondition(files.count == 3, "at most latest and last failure per account")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            precondition(!text.contains("synthetic-secret") && !text.contains("example@test.invalid"))
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            precondition((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        }
        print("PASS: bounded files, duplicate failures omitted, both copies redacted and private")

        accountStore.isEnabled = false
        accountStore.record(firstRecovery)
        precondition(accountStore.latestRecords().contains { $0.outcome == .authRequired })
        print("PASS: disabling diagnostics prevents writes")

        let legacyData = try JSONEncoder().encode(failure)
        let legacyRecord = try JSONDecoder().decode(RefreshDebugRecord.self, from: legacyData)
        precondition(legacyRecord.accountID == nil)
        precondition(DiagnosticsStore(baseDirectory: directory).latestRecords().contains { $0.accountID == nil })
        print("PASS: pre-update diagnostic records remain readable without account attribution")

        accountStore.isEnabled = true
        let blocked = RefreshDebugRecord(timestamp: Date(timeIntervalSince1970: 4), service: .claude,
            outcome: .navigationBlocked, pageTitle: "", url: "about:blank",
            bodyPreview: "", segments: [], message: "popup blocked", accountID: firstAccount)
        accountStore.record(blocked)
        precondition(accountStore.latestRecords().contains { $0.outcome == .authRequired })
        print("PASS: blocked navigation does not overwrite the last terminal refresh failure")
    }
}
