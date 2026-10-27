import AppKit
import Foundation
import TokenMonitorCore
import WebKit

@MainActor final class FixtureWebView: WKWebView {
    var fixtureURL: URL
    var loadCount = 0
    var holdJavaScript = false
    var completions: [@MainActor @Sendable (Any?, Error?) -> Void] = []

    init(configuration: WKWebViewConfiguration, url: URL) {
        fixtureURL = url
        super.init(frame: NSRect(x: 0, y: 0, width: 1440, height: 2200), configuration: configuration)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func load(_ request: URLRequest) -> WKNavigation? {
        loadCount += 1
        return super.load(URLRequest(url: fixtureURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
    }

    override func evaluateJavaScript(_ javaScriptString: String,
        completionHandler: (@MainActor @Sendable (Any?, Error?) -> Void)? = nil) {
        if holdJavaScript, let completionHandler { completions.append(completionHandler) }
        else { super.evaluateJavaScript(javaScriptString, completionHandler: completionHandler) }
    }
}

@MainActor final class RecoveryProof: NSObject, NSApplicationDelegate {
    final class Fixtures {
        var views: [FixtureWebView] = []
        var path = "/hang"
    }
    let root: URL
    let output: URL
    var failures: [String] = []
    var checks = 0
    var results: [[String: Any]] = []

    init(root: URL, output: URL) { self.root = root; self.output = output }

    func check(_ condition: Bool, _ label: String) {
        checks += 1
        if !condition { failures.append(label) }
        results.append(["passed": condition, "check": label])
        print("\(condition ? "PASS" : "FAIL"): \(label)")
        fflush(stdout)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await run() }
            catch { failures.append("Unexpected error: \(error)"); print("ERROR: \(error)") }
            print("RESULT: \(checks) checks, \(failures.count) failures")
            if let data = try? JSONSerialization.data(withJSONObject: ["checks": results, "failures": failures], options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output.appendingPathComponent("result.json"))
            }
            fflush(stdout)
            exit(failures.isEmpty ? 0 : 1)
        }
    }

    func run() async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let diagnostics = DiagnosticsStore(baseDirectory: output, isEnabled: true)
        let store = WKWebsiteDataStore.nonPersistent()
        let fixtures = Fixtures()
        let controller = ServiceSessionController(service: .claude, diagnosticsStore: diagnostics, dataStore: store,
            refreshTimeout: .seconds(2), backgroundWebViewFactory: { configuration in
                let view = FixtureWebView(configuration: configuration, url: URL(string: fixtures.path, relativeTo: self.root)!)
                fixtures.views.append(view)
                return view
            })
        let canary = HTTPCookie(properties: [.domain: "127.0.0.1", .path: "/", .name: "synthetic-session", .value: "fixture"])!
        await store.httpCookieStore.setCookie(canary)
        do { _ = try await controller.refresh(); check(false, "stalled main resource times out") }
        catch { check(error.localizedDescription == SessionControllerError.refreshTimedOut.localizedDescription,
                      "stalled main resource times out") }
        check(fixtures.views.count == 2, "timeout replaces the failed background WebView")
        check(fixtures.views.allSatisfy { $0.configuration.websiteDataStore === store }, "replacement keeps the identical account data store")
        check(await store.httpCookieStore.allCookies().contains { $0.name == "synthetic-session" }, "timeout retains the synthetic sign-in cookie")

        fixtures.path = "/usage?used=100"
        fixtures.views.last!.fixtureURL = URL(string: fixtures.path, relativeTo: root)!
        do {
            let exhausted = try await controller.refresh()
            check(exhausted.metrics.first { $0.key == "weekly-all-models" }?.progress == 0, "exhausted weekly quota remains 0 remaining")
        } catch { check(false, "exhausted quota refresh succeeds: \(error)") }

        fixtures.path = "/hang"
        fixtures.views.last!.fixtureURL = URL(string: fixtures.path, relativeTo: root)!
        let terminatedView = fixtures.views.last!
        let interrupted = Task { try await controller.refresh() }
        try await Task.sleep(for: .milliseconds(100))
        (controller as WKNavigationDelegate).webViewWebContentProcessDidTerminate?(terminatedView)
        do { _ = try await interrupted.value; check(false, "process termination ends the pending refresh") }
        catch {
            let failure = error as NSError
            check(failure.domain == WKError.errorDomain && failure.code == WKError.webContentProcessTerminated.rawValue,
                  "process termination is reported immediately as a WebKit failure")
        }
        check(fixtures.views.count == 3, "process termination replaces only the failed WebView")

        fixtures.path = "/usage?used=0&blocked-image=1"
        fixtures.views.last!.fixtureURL = URL(string: fixtures.path, relativeTo: root)!
        do {
            let reset = try await controller.refresh()
            check(reset.metrics.first { $0.key == "weekly-all-models" }?.progress == 1, "new weekly quota is read despite a stalled image")
            check(fixtures.views.last!.isLoading, "snapshot is read before the stalled subresource finishes")
        } catch { check(false, "new weekly quota is read despite a stalled image: \(error)") }
        check(await store.httpCookieStore.allCookies().contains { $0.name == "synthetic-session" }, "recovery never clears the account cookie")

        let late = Fixtures()
        late.path = "/usage?used=100"
        let lateController = ServiceSessionController(service: .claude, diagnosticsStore: diagnostics, dataStore: store,
            refreshTimeout: .seconds(3), backgroundWebViewFactory: { configuration in
                let view = FixtureWebView(configuration: configuration, url: URL(string: late.path, relativeTo: self.root)!)
                view.holdJavaScript = true
                late.views.append(view)
                return view
            })
        let oldRequest = Task { try await lateController.refresh() }
        for _ in 0..<75 {
            if late.views.first?.completions.count == 1 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let lateView = late.views[0]
        check(lateView.completions.count == 1, "a pending JavaScript evaluation is reproduced")
        lateController.cancelRefresh()
        do { _ = try await oldRequest.value; check(false, "cancellation ends the old refresh") }
        catch { check(error is CancellationError, "cancellation ends the old refresh") }
        lateView.fixtureURL = URL(string: "/usage?used=0", relativeTo: root)!
        let newRequest = Task { try await lateController.refresh() }
        for _ in 0..<75 {
            if lateView.completions.count == 2 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        check(lateView.completions.count == 2, "the next refresh can begin while the old callback is outstanding")
        func payload(used: Int) throws -> String {
            let extract = ServicePageExtract(service: .claude, pageTitle: "Synthetic usage", url: root.absoluteString,
                bodyText: "Current session\nResets at 12:00 PM\n0% used\nAll models\nResets Friday at 5:00 AM\n\(used)% used", segments: [])
            return String(decoding: try JSONEncoder().encode(extract), as: UTF8.self)
        }
        if lateView.completions.count == 2 {
            lateView.completions[0](try payload(used: 100), nil)
            lateView.completions[1](try payload(used: 0), nil)
            let fresh = try await newRequest.value
            check(fresh.metric(for: "weekly-all-models")?.progress == 1, "a late pre-reset callback cannot complete the post-reset refresh")
        } else { lateController.cancelRefresh(); _ = try? await newRequest.value }

        fixtures.views.last!.fixtureURL = URL(string: "/login", relativeTo: root)!
        let countBeforeLogin = fixtures.views.count
        do { _ = try await controller.refresh(); check(false, "a genuine login page is not reported as fresh usage") }
        catch let error as UsageParseError {
            if case .authRequired = error { check(true, "a genuine login page remains authRequired") }
            else { check(false, "a genuine login page remains authRequired") }
        }
        check(fixtures.views.count == countBeforeLogin, "login errors do not trigger a reload loop")

        fixtures.path = "/hang"
        fixtures.views.last!.fixtureURL = URL(string: fixtures.path, relativeTo: root)!
        let networkTimeout = Task { try await controller.refresh() }
        try await Task.sleep(for: .milliseconds(100))
        controller.webView(fixtures.views.last!, didFailProvisionalNavigation: nil,
            withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))
        _ = try? await networkTimeout.value
        check(fixtures.views.count == countBeforeLogin + 1, "a URL-loading timeout also replaces the failed reader")
        check(fixtures.views.last!.configuration.websiteDataStore === store, "URL-loading recovery retains the same account store")
    }
}

@main @MainActor struct SessionRecoveryMain {
    static func main() {
        precondition(Bundle.main.bundleIdentifier == "com.mediapublishing.tokenmonitor.session-recovery-proof")
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let delegate = RecoveryProof(root: URL(string: CommandLine.arguments[1])!, output: URL(fileURLWithPath: CommandLine.arguments[2]))
        app.delegate = delegate
        app.run()
    }
}
