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
        #expect(dashboardView.contains("ProgressTrack(progress: progress, tint: tintColor)"))
        #expect(dashboardView.contains("Text(displayValueText)"))
        #expect(dashboardView.contains("isUsedPercentageMetric"))
        #expect(dashboardView.contains("% remaining"))
        #expect(!dashboardView.contains("showsProgressPercentage"))
        #expect(!dashboardView.contains("ScrollView"))
        #expect(dashboardView.contains("ServiceSectionView(status: status)"))
        #expect(dashboardView.contains("count: 3"))
        #expect(dashboardView.contains("Image(systemName: \"arrow.clockwise\")"))
        #expect(dashboardView.contains("minHeight: 58"))
        #expect(dashboardView.contains("model.showUsageDetails"))
        #expect(dashboardView.contains("height: model.desiredPopoverHeight()"))
        #expect(dashboardView.contains("extra-usage-spend"))
        #expect(dashboardView.contains("monthly-spend-limit"))
        #expect(dashboardView.contains("current-balance"))
        #expect(dashboardView.contains("monthly-limit-balance"))
        #expect(dashboardView.contains("Monthly limit / Balance"))
        #expect(appDelegate.contains("model.statusMenuUsesColor"))
        #expect(appDelegate.contains("model.statusMenuShowsPercentages"))
        #expect(appDelegate.contains("showsBothLimits ? 74 : 56"))
        #expect(appDelegate.contains("model.statusMenuShowsPercentages ? 21 : 18"))
        #expect(appDelegate.contains("services.count > 2 ? 5 : 6"))
        #expect(appDelegate.contains("model.statusMenuServices"))
        #expect(appDelegate.contains("model.statusMenuScores(for: service)"))
        #expect(appDelegate.contains("model.$statusMenuLimitDisplay"))
        #expect(appDelegate.contains("drawCombinedBar"))
        #expect(appDelegate.contains("drawStatusPair"))
        #expect(appDelegate.contains("let rowHeight"))
        #expect(appDelegate.contains("let barHeight"))
        #expect(appDelegate.contains("drawStatusValue"))
        #expect(appDelegate.contains("button.effectiveAppearance"))
        #expect(appDelegate.contains("statusBarForegroundColor"))
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
        #expect(appModel.contains("Keys.statusMenuLimitDisplay: StatusMenuLimitDisplay.total.rawValue"))
        #expect(appModel.contains("case both"))
        #expect(appModel.contains("showUsageDetails ? 650 : 540"))
        #expect(appModel.contains("snapshot.statusMenuSessionScore, snapshot.statusMenuTotalScore"))
        #expect(appDelegate.contains("Menu bar: Session / Total"))
        #expect(appModel.contains("Keys.showUsageDetails: false"))
        #expect(!appModel.contains("dashboardShowsProgressPercentages"))
        #expect(appModel.contains("openGitHubDebugReportDraft"))
        #expect(appModel.contains("openEmailDebugReportDraft"))
        #expect(diagnosticsStore.contains("guard isEnabled else"))
        #expect(settingsView.contains("Enable debug mode"))
        #expect(settingsView.contains("Status menu"))
        #expect(settingsView.contains("Use colored status bars"))
        #expect(settingsView.contains("Show percentages in menu bar"))
        #expect(settingsView.contains("Limit display"))
        #expect(settingsView.contains("pickerStyle(.segmented)"))
        #expect(settingsView.contains("Show usage details"))
        #expect(!settingsView.contains("Show percentages in dashboard bars"))
        #expect(settingsView.contains("GitHub Issue Draft"))
        #expect(settingsView.contains("Email Draft"))
        #expect(appDelegate.contains("drawStatusValue"))
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

    @Test func reconnectRecoversFromAStuckProviderRefresh() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let appModel = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppModel.swift"),
            encoding: .utf8
        )
        let sessionCoordinator = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/SessionCoordinator.swift"),
            encoding: .utf8
        )
        let sessionController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceSessionController.swift"),
            encoding: .utf8
        )

        #expect(appModel.contains("pendingForcedRefreshes"))
        #expect(appModel.contains("sessionCoordinator.cancelRefresh(service: service)"))
        #expect(appModel.contains("catch is CancellationError"))
        #expect(sessionCoordinator.contains("func cancelRefresh(service: ServiceKind)"))
        #expect(sessionController.contains("func cancelRefresh()"))
        #expect(sessionController.contains("scheduleRefreshTimeout"))
        #expect(sessionController.contains("Usage page refresh timed out"))
    }

    @Test func openCodeGoIsOptInAndHiddenUntilItHasASnapshot() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let appModel = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppModel.swift"),
            encoding: .utf8
        )
        let settingsView = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/SettingsView.swift"),
            encoding: .utf8
        )
        let sessionController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceSessionController.swift"),
            encoding: .utf8
        )
        let loginController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceLoginWindowController.swift"),
            encoding: .utf8
        )

        #expect(appModel.contains("Keys.openCodeGoEnabled: false"))
        #expect(appModel.contains("!openCodeGoEnabled || status.snapshot == nil"))
        #expect(appModel.contains("service != .openCodeGo || openCodeGoEnabled"))
        #expect(settingsView.contains("status.service.displayName"))
        #expect(settingsView.contains("settingsProviderStatuses"))
        #expect(sessionController.contains("extract.openCodeGoWorkspaceURL"))
        #expect(sessionController.contains("OpenCodeGoUsageParser()"))
        #expect(loginController.contains("isOpenCodeGoWorkspaceURL(currentURL)"))
        #expect(loginController.contains("hasSubscriptionMessage"))
    }

    @Test func providersCanDisconnectOrSwitchAccountsWithoutClearingOtherProviders() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let appModel = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/AppModel.swift"),
            encoding: .utf8
        )
        let settingsView = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/SettingsView.swift"),
            encoding: .utf8
        )
        let sessionController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceSessionController.swift"),
            encoding: .utf8
        )
        let loginController = try String(
            contentsOf: rootURL.appendingPathComponent("Sources/TokenMonitorApp/ServiceLoginWindowController.swift"),
            encoding: .utf8
        )

        #expect(settingsView.contains("Switch account..."))
        #expect(settingsView.contains("Disconnect"))
        #expect(settingsView.contains("model.switchAccount(for: status.service)"))
        #expect(appModel.contains("func disconnect(_ service: ServiceKind)"))
        #expect(appModel.contains("replacingExistingSession: true"))
        #expect(sessionController.contains("websiteDataBelongsToService"))
        #expect(sessionController.contains("record.displayName"))
        #expect(sessionController.contains("cookie.domain"))
        #expect(sessionController.contains("serviceWebsiteHosts"))
        #expect(sessionController.contains("openai.com"))
        #expect(sessionController.contains("anthropic.com"))
        #expect(sessionController.contains("opencode.ai"))
        #expect(!sessionController.contains("google.com"))
        #expect(!sessionController.contains("removeData(ofTypes: dataTypes, modifiedSince:"))
        #expect(loginController.contains("forcesGoogleAccountSelection = true"))
        #expect(loginController.contains("prompt"))
        #expect(loginController.contains("select_account"))
        #expect(loginController.contains("login_hint"))
        #expect(loginController.contains("authuser"))
        #expect(loginController.contains("accounts.google.com"))
        #expect(settingsView.contains("model.disconnect(status.service)"))
        #expect(settingsView.contains("providerHasAccountActions"))
    }
}
