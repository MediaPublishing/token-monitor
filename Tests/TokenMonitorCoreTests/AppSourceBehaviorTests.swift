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

        #expect(!loginWindowController.contains("orderFrontRegardless"))
        #expect(!sessionController.contains("beginBackgroundRefreshPresentationIfNeeded"))
        #expect(!sessionController.contains("endBackgroundPresentationIfNeeded"))
    }
}
