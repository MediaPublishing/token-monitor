import Foundation
import Testing

struct UpdateConfigurationTests {
    @Test func appInfoPlistContainsSparkleDefaults() throws {
        let rootURL = repositoryRootURL()
        let plistURL = rootURL
            .appendingPathComponent("Sources/TokenMonitorApp/Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])

        #expect(plist["SUFeedURL"] as? String == "https://mediapublishing.github.io/token-monitor/appcast.xml")
        #expect(plist["SUPublicEDKey"] as? String == "MaN6KO95WRBx46C9MgCneLyaladlp5XPxnIt+p/R860=")
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == false)
        #expect(plist["SUAllowsAutomaticUpdates"] as? Bool == true)
        #expect(plist["SUScheduledCheckInterval"] as? Int == 3600)
    }

    @Test func automaticChecksPreservePreferencesAndSupportVisibleBackgroundReminders() throws {
        let controllerURL = repositoryRootURL()
            .appendingPathComponent("Sources/TokenMonitorApp/AppUpdateController.swift")
        let controller = try String(contentsOf: controllerURL, encoding: .utf8)

        #expect(!controller.contains("automaticallyChecksForUpdates = false"))
        #expect(controller.contains("updaterDelegate: self"))
        #expect(controller.contains("userDriverDelegate: self"))
        #expect(controller.contains("supportsGentleScheduledUpdateReminders"))
        #expect(controller.contains("checkForUpdatesInBackground()"))
        #expect(controller.contains("diagnosticsText"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
