import Foundation
import Testing

struct AppSourceBehaviorTests {
    @Test func automaticChatGPTRefreshDoesNotOrderAWindowToTheFront() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let loginWindowController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceLoginWindowController.swift"),
            encoding: .utf8
        )
        let sessionController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceSessionController.swift"),
            encoding: .utf8
        )
        let appModel = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppModel.swift"),
            encoding: .utf8
        )

        #expect(!loginWindowController.contains("orderFrontRegardless"))
        #expect(!loginWindowController.contains("removeData(ofTypes:"))
        #expect(!sessionController.contains("browserController.loadUsagePage()"))
        #expect(!sessionController.contains("browserController.evaluateJavaScript"))
        #expect(!sessionController.contains("WKWebsiteDataStore(forIdentifier:"))
        #expect(sessionController.contains("WKWebsiteDataStore.default()"))
        #expect(!sessionController.contains("beginBackgroundRefreshPresentationIfNeeded"))
        #expect(!sessionController.contains("endBackgroundPresentationIfNeeded"))
        #expect(sessionController.contains("decidePolicyFor navigationAction"))
        #expect(sessionController.contains("createWebViewWith configuration"))
        #expect(sessionController.contains("javaScriptCanOpenWindowsAutomatically = false"))
        #expect(sessionController.contains("recordBlockedNavigation"))
        #expect(sessionController.contains("allowsEmbeddedWebNavigation"))
        #expect(appModel.contains("shouldSkipAutomaticRefresh"))
        #expect(appModel.contains("case .launch, .background"))
    }

    @Test func remainingProgressBarsUseThresholdColors() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let dashboardView = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/DashboardPopoverView.swift"),
            encoding: .utf8
        )
        let appDelegate = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(dashboardView.contains("if progress >= 0.75"))
        #expect(dashboardView.contains("if progress >= 0.5"))
        #expect(dashboardView.contains("if progress >= 0.25"))
        #expect(dashboardView.contains("return .red"))
        #expect(dashboardView.contains("1 - clamped"))
        #expect(dashboardView.contains("ProgressTrack(progress: progress, tint: tintColor, label:"))
        #expect(dashboardView.contains("guard showsProgressPercentage else"))
        #expect(dashboardView.contains("monthly-limit-balance"))
        #expect(dashboardView.contains("Monthly limit / Balance"))
        #expect(appDelegate.contains("model.statusMenuUsesColor"))
        #expect(appDelegate.contains("model.statusMenuShowsPercentages"))
        #expect(appDelegate.contains("drawBarLabel(label, in: rect"))
        #expect(appDelegate.contains("button.attributedTitle = NSAttributedString(string: \"\")"))
        #expect(appDelegate.contains("if score >= 0.75 { return .systemGreen }"))
        #expect(appDelegate.contains("if score >= 0.5 { return .systemMint }"))
        #expect(appDelegate.contains("if score >= 0.25 { return .systemOrange }"))
        #expect(!dashboardView.contains("localizedCaseInsensitiveContains(\"remaining\") {\n            return .green"))
    }

    @Test func debugReportingRequiresExplicitModeAndUsesDrafts() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let appModel = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppModel.swift"),
            encoding: .utf8
        )
        let diagnosticsStore = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/DiagnosticsStore.swift"),
            encoding: .utf8
        )
        let settingsView = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/SettingsView.swift"),
            encoding: .utf8
        )
        let appDelegate = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appModel.contains("Keys.debugModeEnabled: false"))
        #expect(appModel.contains("Keys.statusMenuUsesColor: true"))
        #expect(appModel.contains("Keys.statusMenuShowsPercentages: false"))
        #expect(appModel.contains("Keys.dashboardShowsProgressPercentages: true"))
        #expect(appModel.contains("openGitHubDebugReportDraft"))
        #expect(appModel.contains("openEmailDebugReportDraft"))
        #expect(diagnosticsStore.contains("guard isEnabled else"))
        #expect(settingsView.contains("Enable debug mode"))
        #expect(settingsView.contains("Status menu"))
        #expect(settingsView.contains("Use colored status bars"))
        #expect(settingsView.contains("Show percentages in menu bar"))
        #expect(settingsView.contains("Show percentages in dashboard bars"))
        #expect(settingsView.contains("GitHub Issue Draft"))
        #expect(settingsView.contains("Email Draft"))
        #expect(appDelegate.contains("drawBarLabel"))
    }

    @Test func claudeExtractionHandlesEmptyAndLocalizedDomText() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let sessionController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceSessionController.swift"),
            encoding: .utf8
        )

        #expect(sessionController.contains("emptyUsagePage"))
        #expect(sessionController.contains("Usage page returned no readable text"))
        #expect(sessionController.contains("document.documentElement"))
        #expect(sessionController.contains("shadowRoot"))
        #expect(sessionController.contains("aria-label"))
        #expect(sessionController.contains("Aktuelle Sitzung"))
        #expect(sessionController.contains("€"))
    }
}
