import Foundation
import Testing

struct MarketingAssetTests {
    @Test func landingPageAndReadmeReferenceLocalTokenMonitorAssets() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let landingHTML = try String(
            contentsOf: rootURL.appendingPathComponent("landing/index.html"),
            encoding: .utf8
        )
        let readme = try String(
            contentsOf: rootURL.appendingPathComponent("README.md"),
            encoding: .utf8
        )

        let expectedAssetPaths = [
            "assets/branding/token-monitor-logo.png",
            "assets/screenshots/app/dashboard.png",
            "assets/screenshots/app/claude.png",
            "assets/screenshots/app/chatgpt.png",
            "assets/screenshots/install/gatekeeper-blocked.png",
            "assets/screenshots/install/gatekeeper-privacy-security.png",
            "assets/screenshots/install/gatekeeper-open-anyway.png",
            "assets/screenshots/install/gatekeeper-admin-confirm.png"
        ]

        for assetPath in expectedAssetPaths {
            #expect(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(assetPath).path))
            #expect(landingHTML.contains(assetPath))
        }

        #expect(readme.contains("## Screenshots"))
        #expect(readme.contains("assets/screenshots/app/dashboard.png"))
        #expect(readme.contains("assets/screenshots/app/claude.png"))
        #expect(readme.contains("assets/screenshots/app/chatgpt.png"))
        #expect(readme.contains("assets/screenshots/install/gatekeeper-blocked.png"))
        #expect(readme.contains("assets/screenshots/install/gatekeeper-privacy-security.png"))
        #expect(readme.contains("assets/screenshots/install/gatekeeper-open-anyway.png"))
        #expect(readme.contains("assets/screenshots/install/gatekeeper-admin-confirm.png"))
        #expect(readme.contains("[Landing page](landing/index.html)"))
    }

    @Test func releaseMaterialsReferenceDmgInstaller() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let readme = try String(
            contentsOf: rootURL.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let landingHTML = try String(
            contentsOf: rootURL.appendingPathComponent("landing/index.html"),
            encoding: .utf8
        )
        let releaseWorkflow = try String(
            contentsOf: rootURL.appendingPathComponent(".github/workflows/release.yml"),
            encoding: .utf8
        )

        let dmgScriptURL = rootURL.appendingPathComponent("scripts/package-dmg.sh")
        #expect(FileManager.default.fileExists(atPath: dmgScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: dmgScriptURL.path))
        #expect(readme.contains("TokenMonitor-macOS.dmg"))
        #expect(readme.contains("Gatekeeper"))
        #expect(readme.contains("notarized"))
        #expect(readme.contains("Open Anyway"))
        #expect(readme.contains("Dennoch öffnen"))
        #expect(readme.contains("Launch at login"))
        #expect(!readme.contains("DMG vs. PKG"))
        #expect(!readme.contains("SPARKLE_PRIVATE_KEY"))
        #expect(!readme.contains("TOKEN_MONITOR_CODESIGN_IDENTITY"))
        #expect(!readme.contains("TOKEN_MONITOR_NOTARIZE"))
        #expect(landingHTML.contains("TokenMonitor-macOS.dmg"))
        #expect(landingHTML.contains("Gatekeeper"))
        #expect(landingHTML.contains("notarized"))
        #expect(landingHTML.contains("Open Anyway"))
        #expect(landingHTML.contains("Dennoch öffnen"))
        #expect(landingHTML.contains("Login Items"))
        #expect(!landingHTML.contains("Would a PKG avoid"))
        #expect(!landingHTML.contains("How do updates work?"))
        #expect(releaseWorkflow.contains("package-release.sh"))
        #expect(releaseWorkflow.contains("dist/TokenMonitor-macOS.dmg"))
    }
}
