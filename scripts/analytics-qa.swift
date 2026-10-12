import AppKit
import SwiftUI
import TokenMonitorCore

@MainActor final class AppDelegate {
    static let shared: AppDelegate? = nil
    static let popoverWidth: CGFloat = 488
    func closePopover() { }
    func showSettingsWindow() { }
}

private struct EmptySnapshots: SnapshotPersisting {
    func loadSnapshots() throws -> [ServiceKind: ServiceSnapshot] { [:] }
    func saveSnapshots(_ snapshots: [ServiceKind: ServiceSnapshot]) throws { }
}
private struct EmptyAccounts: AccountPersisting {
    func loadAccounts() throws -> [MonitoredAccount] { [] }
    func saveAccounts(_ accounts: [MonitoredAccount]) throws { }
}

@MainActor private struct QAView: View {
    @ObservedObject var model: AppModel
    @State private var dark = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Synthetic test data").font(.caption)
                Spacer()
                Toggle("Dark", isOn: $dark)
            }.padding(10)
            PopoverRootView().environmentObject(model)
        }
        .frame(width: 488)
        .preferredColorScheme(dark ? .dark : .light)
    }
}

@main @MainActor struct AnalyticsQA {
    static func main() throws {
        let home = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1])
            : Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("analytics-qa-home")
        let roots = [home.appendingPathComponent(".codex/sessions"), home.appendingPathComponent(".claude/projects/demo")]
        for root in roots { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
        let stamp = Date().ISO8601Format()
        for (i, name) in ["Token Monitor", "Newsletter", "Second Brain", "Website"].enumerated() {
            let path = home.appendingPathComponent("Projects/" + name).path
            let tokens = (4 - i) * 250000
            let usage: [String: Any] = ["input_tokens": tokens, "cached_input_tokens": tokens / 2, "output_tokens": tokens / 10]
            let rows: [[String: Any]] = [
                ["type": "session_meta", "payload": ["id": "demo-\(i)", "cwd": path, "timestamp": stamp]],
                ["type": "event_msg", "timestamp": stamp, "payload": ["type": "token_count", "info": ["total_token_usage": usage, "last_token_usage": usage]]]
            ]
            let data = try rows.map { try JSONSerialization.data(withJSONObject: $0) + Data([10]) }.reduce(Data(), +)
            try data.write(to: roots[0].appendingPathComponent("demo-\(i).jsonl"))
            let claude: [String: Any] = ["type": "assistant", "sessionId": "claude-demo-\(i)", "cwd": path, "timestamp": stamp,
                "message": ["id": "msg-\(i)", "model": "example", "usage": ["input_tokens": tokens / 2, "output_tokens": tokens / 10]]]
            try (JSONSerialization.data(withJSONObject: claude) + Data([10])).write(to: roots[1].appendingPathComponent("demo-\(i).jsonl"))
        }
        let defaults = UserDefaults(suiteName: "com.mediapublishing.tokenmonitor.analytics-qa-fixtures")!
        defaults.removePersistentDomain(forName: "com.mediapublishing.tokenmonitor.analytics-qa-fixtures")
        let analytics = ProjectAnalyticsModel(defaults: defaults, home: home)
        precondition(!analytics.enabled && analytics.groups.isEmpty && analytics.capturedAt == nil)
        analytics.setEnabled(true)
        let model = AppModel(snapshotStore: EmptySnapshots(), accountStore: EmptyAccounts(), analytics: analytics)
        model.showAnalyticsInPopover()
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        if CommandLine.arguments.contains("--proof") {
            guard let flag = CommandLine.arguments.firstIndex(of: "--proof"), CommandLine.arguments.count > flag + 1 else {
                fatalError("--proof requires an output directory")
            }
            let output = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                Task { @MainActor in
                    do {
                        try await NativeLayoutProof.run(analytics: analytics, output: output)
                        app.terminate(nil)
                    } catch {
                        print("NATIVE_LAYOUT_PROOF_FAILED: \(error)")
                        fflush(stdout)
                        exit(1)
                    }
                }
            }
            app.run()
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 200, y: 120, width: 488, height: 700),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Token Monitor Analytics QA"
        window.contentViewController = NSHostingController(rootView: QAView(model: model))
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            Task { @MainActor in
                precondition(analytics.groups.count == 4 && analytics.totalTokens == 4_250_000)
                analytics.setSource(.claudeCode, enabled: false)
                for _ in 0..<100 where analytics.refreshing { try? await Task.sleep(for: .milliseconds(20)) }
                precondition(analytics.totalTokens == 2_750_000 && analytics.sources.count == 1)
                analytics.setEnabled(false)
                analytics.refresh()
                precondition(analytics.groups.isEmpty && !analytics.refreshing && analytics.capturedAt == nil)
                analytics.setSource(.claudeCode, enabled: true)
                analytics.setEnabled(true)
                for _ in 0..<100 where analytics.refreshing { try? await Task.sleep(for: .milliseconds(20)) }
                analytics.assign(keys: [home.appendingPathComponent("Projects/Token Monitor").path], projectName: "", topic: "Entwicklung")
                analytics.assign(keys: [home.appendingPathComponent("Projects/Newsletter").path], projectName: "", topic: "Content")
                let restored = ProjectAnalyticsModel(defaults: UserDefaults(suiteName: "com.mediapublishing.tokenmonitor.analytics-qa-fixtures")!, home: home)
                precondition(restored.assignment(for: home.appendingPathComponent("Projects/Token Monitor").path).topic == "Entwicklung")
                analytics.grouping = .topics
                precondition(analytics.groups.count == 3 && analytics.totalTokens == 4_250_000)
                analytics.grouping = .projects
                print("QA_SYNTHETIC_TOTAL=4250000 GROUPS=4 SOURCES=2 DISABLED_DEFAULT=PASS SOURCE_EXCLUSION=PASS DISABLE=PASS ASSIGNMENT_PERSISTENCE=PASS TOPICS=PASS")
                try? Data("PASS: totals, sources, disabled state, assignment persistence, topics\n".utf8).write(to: home.appendingPathComponent("qa-proof.txt"))
                fflush(stdout)
            }
        }
        app.run()
    }
}
