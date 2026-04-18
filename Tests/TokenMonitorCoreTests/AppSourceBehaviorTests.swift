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
}
