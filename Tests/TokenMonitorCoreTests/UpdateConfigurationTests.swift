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
    }

    @Test func automaticUpdateChecksRequireExplicitUserConfiguration() throws {
        let controllerURL = repositoryRootURL()
            .appendingPathComponent("Sources/TokenMonitorApp/AppUpdateController.swift")
        let controller = try String(contentsOf: controllerURL, encoding: .utf8)

        #expect(controller.contains("automaticUpdateChecksConfigured"))
        #expect(controller.contains("updaterController.updater.automaticallyChecksForUpdates = false"))
        #expect(controller.contains("UserDefaults.standard.set(true, forKey: Self.automaticUpdateChecksConfiguredKey)"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
