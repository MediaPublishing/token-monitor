import Foundation
import Testing

struct UpdateConfigurationTests {
    @Test func appInfoPlistContainsSparkleDefaults() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TokenMonitorApp/Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])

        #expect(plist["SUFeedURL"] as? String == "https://mediapublishing.github.io/token-monitor/appcast.xml")
        #expect(plist["SUPublicEDKey"] as? String == "MaN6KO95WRBx46C9MgCneLyaladlp5XPxnIt+p/R860=")
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(plist["SUAllowsAutomaticUpdates"] as? Bool == true)
    }
}
