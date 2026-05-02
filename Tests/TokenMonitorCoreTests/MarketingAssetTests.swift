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
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_CODESIGN_IDENTITY"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_NOTARY_APP_PASSWORD"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_NOTARIZE=1"))
        #expect(releaseWorkflow.contains("Developer ID signing is not configured; skipping notarization."))
    }

    @Test func appleDistributionReadinessDocCoversReleasePaths() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let readme = try String(
            contentsOf: rootURL.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let distributionDocURL = rootURL.appendingPathComponent("docs/apple-distribution-readiness.md")
        let distributionDoc = try String(contentsOf: distributionDocURL, encoding: .utf8)
        let credentialRunbookURL = rootURL.appendingPathComponent("docs/apple-credential-runbook.md")
        let credentialRunbook = try String(contentsOf: credentialRunbookURL, encoding: .utf8)
        let readinessScriptURL = rootURL.appendingPathComponent("scripts/check-apple-distribution.sh")
        let readinessScript = try String(contentsOf: readinessScriptURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: distributionDocURL.path))
        #expect(FileManager.default.fileExists(atPath: credentialRunbookURL.path))
        #expect(FileManager.default.fileExists(atPath: readinessScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: readinessScriptURL.path))
        #expect(readme.contains("docs/apple-distribution-readiness.md"))
        #expect(readme.contains("docs/apple-credential-runbook.md"))
        #expect(distributionDoc.contains("docs/apple-credential-runbook.md"))
        #expect(distributionDoc.contains("scripts/check-apple-distribution.sh"))
        #expect(distributionDoc.contains("Developer ID DMG"))
        #expect(distributionDoc.contains("Mac App Store Feasibility"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_CODESIGN_IDENTITY"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_NOTARIZE"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_NOTARY_APP_PASSWORD"))
        #expect(distributionDoc.contains("App Store Connect API"))
        #expect(distributionDoc.contains("Marketing Setup"))
        #expect(distributionDoc.contains("Ongoing Issue-Fixing Loop"))
        #expect(readinessScript.contains("notarytool"))
        #expect(readinessScript.contains("stapler"))
        #expect(readinessScript.contains("Developer ID Application"))
        #expect(readinessScript.contains("TOKEN_MONITOR_NOTARY_PROFILE"))
        #expect(credentialRunbook.contains("Do not share Apple ID passwords"))
        #expect(credentialRunbook.contains("base64 -i /path/to/DeveloperIDApplication.p12"))
        #expect(credentialRunbook.contains("TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64"))
        #expect(credentialRunbook.contains("TOKEN_MONITOR_NOTARY_APP_PASSWORD"))
        #expect(credentialRunbook.contains("SPARKLE_PRIVATE_KEY"))
        #expect(credentialRunbook.contains("xcrun notarytool store-credentials token-monitor-notary"))
    }

    @Test func publicIssueTemplatesProtectPrivateDebugData() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let distributionDoc = try String(
            contentsOf: rootURL.appendingPathComponent("docs/apple-distribution-readiness.md"),
            encoding: .utf8
        )
        let parserIssueTemplateURL = rootURL.appendingPathComponent(".github/ISSUE_TEMPLATE/parser-layout-bug.yml")
        let issueConfigURL = rootURL.appendingPathComponent(".github/ISSUE_TEMPLATE/config.yml")
        let parserIssueTemplate = try String(contentsOf: parserIssueTemplateURL, encoding: .utf8)
        let issueConfig = try String(contentsOf: issueConfigURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: parserIssueTemplateURL.path))
        #expect(FileManager.default.fileExists(atPath: issueConfigURL.path))
        #expect(distributionDoc.contains(".github/ISSUE_TEMPLATE/parser-layout-bug.yml"))
        #expect(parserIssueTemplate.contains("GitHub Issues are public"))
        #expect(parserIssueTemplate.contains("Do not attach raw debug dumps"))
        #expect(parserIssueTemplate.contains("chat titles"))
        #expect(parserIssueTemplate.contains("usage budgets"))
        #expect(parserIssueTemplate.contains("Token Monitor version"))
        #expect(parserIssueTemplate.contains("Account language or locale"))
        #expect(parserIssueTemplate.contains("Privacy check"))
        #expect(issueConfig.contains("blank_issues_enabled: false"))
        #expect(!parserIssueTemplate.contains("info@etraininghq.com"))
        #expect(!issueConfig.contains("info@etraininghq.com"))
    }

    @Test func marketingLaunchKitCoversDistributionMetadata() throws {
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
        let distributionDoc = try String(
            contentsOf: rootURL.appendingPathComponent("docs/apple-distribution-readiness.md"),
            encoding: .utf8
        )
        let launchKitURL = rootURL.appendingPathComponent("docs/marketing-launch-kit.md")
        let launchKit = try String(contentsOf: launchKitURL, encoding: .utf8)
        let privacyURL = rootURL.appendingPathComponent("docs/privacy.md")
        let privacy = try String(contentsOf: privacyURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: launchKitURL.path))
        #expect(FileManager.default.fileExists(atPath: privacyURL.path))
        #expect(readme.contains("docs/marketing-launch-kit.md"))
        #expect(readme.contains("docs/privacy.md"))
        #expect(landingHTML.contains("docs/privacy.md"))
        #expect(distributionDoc.contains("docs/marketing-launch-kit.md"))
        #expect(launchKit.contains("Direct Distribution Listing"))
        #expect(launchKit.contains("Mac App Store Draft Metadata"))
        #expect(launchKit.contains("Privacy label draft"))
        #expect(launchKit.contains("https://github.com/MediaPublishing/token-monitor/blob/main/docs/privacy.md"))
        #expect(launchKit.contains("Review notes draft"))
        #expect(launchKit.contains("Screenshot Inventory"))
        #expect(launchKit.contains("Launch Checklist"))
        #expect(launchKit.contains("Approval Gates"))
        #expect(launchKit.contains("https://mediapublishing.github.io/token-monitor/"))
        #expect(launchKit.contains("https://github.com/MediaPublishing/token-monitor/issues"))
        #expect(launchKit.contains("Token Monitor is not affiliated with Anthropic, OpenAI, or Apple."))
        #expect(privacy.contains("does not send usage data to Token Monitor server infrastructure"))
        #expect(privacy.contains("Provider login sessions managed by WebKit"))
        #expect(privacy.contains("Debug mode is off by default"))
        #expect(privacy.contains("GitHub Issues are public"))
    }
}
