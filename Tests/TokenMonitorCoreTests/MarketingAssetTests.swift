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
        let publicReleaseVerifierURL = rootURL.appendingPathComponent("scripts/verify-public-release.sh")
        let publicReleaseVerifier = try String(contentsOf: publicReleaseVerifierURL, encoding: .utf8)

        let dmgScriptURL = rootURL.appendingPathComponent("scripts/package-dmg.sh")
        #expect(FileManager.default.fileExists(atPath: dmgScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: dmgScriptURL.path))
        #expect(FileManager.default.fileExists(atPath: publicReleaseVerifierURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: publicReleaseVerifierURL.path))
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
        #expect(publicReleaseVerifier.contains("TokenMonitor-macOS.dmg"))
        #expect(publicReleaseVerifier.contains("TokenMonitor-macOS.zip"))
        #expect(publicReleaseVerifier.contains("appcast.xml"))
        #expect(publicReleaseVerifier.contains("updates/$UPDATE_ZIP_NAME"))
        #expect(publicReleaseVerifier.contains("TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1"))
        #expect(publicReleaseVerifier.contains("spctl --assess --type open"))
        #expect(publicReleaseVerifier.contains("xcrun stapler validate"))
        #expect(publicReleaseVerifier.contains("dist/public-release-verification"))
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
        let masFeasibilityURL = rootURL.appendingPathComponent("docs/mac-app-store-feasibility.md")
        let masFeasibility = try String(contentsOf: masFeasibilityURL, encoding: .utf8)
        let masEntitlementsURL = rootURL.appendingPathComponent("packaging/TokenMonitorMAS.entitlements")
        let masEntitlements = try String(contentsOf: masEntitlementsURL, encoding: .utf8)
        let legalChecklistURL = rootURL.appendingPathComponent("docs/publication-legal-checklist.md")
        let legalChecklist = try String(contentsOf: legalChecklistURL, encoding: .utf8)
        let readinessScriptURL = rootURL.appendingPathComponent("scripts/check-apple-distribution.sh")
        let readinessScript = try String(contentsOf: readinessScriptURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: distributionDocURL.path))
        #expect(FileManager.default.fileExists(atPath: credentialRunbookURL.path))
        #expect(FileManager.default.fileExists(atPath: masFeasibilityURL.path))
        #expect(FileManager.default.fileExists(atPath: masEntitlementsURL.path))
        #expect(FileManager.default.fileExists(atPath: legalChecklistURL.path))
        #expect(FileManager.default.fileExists(atPath: readinessScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: readinessScriptURL.path))
        #expect(readme.contains("docs/apple-distribution-readiness.md"))
        #expect(readme.contains("docs/apple-credential-runbook.md"))
        #expect(readme.contains("docs/mac-app-store-feasibility.md"))
        #expect(readme.contains("docs/publication-legal-checklist.md"))
        #expect(distributionDoc.contains("docs/apple-credential-runbook.md"))
        #expect(distributionDoc.contains("docs/mac-app-store-feasibility.md"))
        #expect(distributionDoc.contains("packaging/TokenMonitorMAS.entitlements"))
        #expect(distributionDoc.contains("docs/publication-legal-checklist.md"))
        #expect(distributionDoc.contains("scripts/check-apple-distribution.sh"))
        #expect(distributionDoc.contains("scripts/verify-public-release.sh"))
        #expect(distributionDoc.contains("Developer ID DMG"))
        #expect(distributionDoc.contains("swift test` passes with 31 tests"))
        #expect(distributionDoc.contains("Mac App Store Feasibility"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_CODESIGN_IDENTITY"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_NOTARIZE"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64"))
        #expect(distributionDoc.contains("TOKEN_MONITOR_NOTARY_APP_PASSWORD"))
        #expect(distributionDoc.contains("App Store Connect API"))
        #expect(distributionDoc.contains("Marketing Setup"))
        #expect(distributionDoc.contains("Ongoing Issue-Fixing Loop"))
        #expect(distributionDoc.contains("Completion Audit"))
        #expect(distributionDoc.contains("The repository is prepared for Apple Developer access."))
        #expect(distributionDoc.contains("No Developer ID Application certificate is installed locally."))
        #expect(distributionDoc.contains("Gatekeeper rejects the current local app and DMG."))
        #expect(distributionDoc.contains("not complete until a signed, notarized, stapled Developer ID release is produced"))
        #expect(distributionDoc.contains("Repository license and final legal/privacy approvals remain human approval gates"))
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
        #expect(masFeasibility.contains("Mac App Store distribution is not ready as-is."))
        #expect(masFeasibility.contains("Remove Sparkle from the MAS binary."))
        #expect(masFeasibility.contains("com.apple.security.app-sandbox"))
        #expect(masFeasibility.contains("packaging/TokenMonitorMAS.entitlements"))
        #expect(masFeasibility.contains("WKWebsiteDataStore.default()"))
        #expect(masFeasibility.contains("SMAppService.mainApp"))
        #expect(masFeasibility.contains("scripts/build-mas-app.sh"))
        #expect(masEntitlements.contains("com.apple.security.app-sandbox"))
        #expect(masEntitlements.contains("com.apple.security.network.client"))
        #expect(legalChecklist.contains("No repository license is published yet."))
        #expect(legalChecklist.contains("Do not choose a software license on behalf of the owner."))
        #expect(legalChecklist.contains("docs/privacy.md"))
        #expect(legalChecklist.contains("SECURITY.md"))
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

    @Test func supportPageRoutesPublicAndPrivateReports() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let readme = try String(
            contentsOf: rootURL.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let launchKit = try String(
            contentsOf: rootURL.appendingPathComponent("docs/marketing-launch-kit.md"),
            encoding: .utf8
        )
        let supportURL = rootURL.appendingPathComponent("SUPPORT.md")
        let support = try String(contentsOf: supportURL, encoding: .utf8)
        let securityURL = rootURL.appendingPathComponent("SECURITY.md")
        let security = try String(contentsOf: securityURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: supportURL.path))
        #expect(FileManager.default.fileExists(atPath: securityURL.path))
        #expect(readme.contains("SUPPORT.md"))
        #expect(readme.contains("SECURITY.md"))
        #expect(launchKit.contains("https://github.com/MediaPublishing/token-monitor/blob/main/SUPPORT.md"))
        #expect(support.contains("GitHub Issues are public"))
        #expect(support.contains("Do not post raw debug dumps"))
        #expect(support.contains("Installation Or Gatekeeper"))
        #expect(support.contains("parser-layout-bug.yml"))
        #expect(support.contains("docs/privacy.md"))
        #expect(support.contains("SECURITY.md"))
        #expect(support.contains("Apple ID passwords"))
        #expect(!support.contains("info@etraininghq.com"))
        #expect(security.contains("Reporting A Vulnerability"))
        #expect(security.contains("Do not open a public issue"))
        #expect(security.contains("GitHub private vulnerability reporting"))
        #expect(security.contains("Developer ID `.p12` files or passwords"))
        #expect(security.contains("docs/privacy.md"))
        #expect(!security.contains("info@etraininghq.com"))
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
        #expect(launchKit.contains("./scripts/verify-public-release.sh <tag> <version> <build>"))
        #expect(launchKit.contains("TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1"))
        #expect(launchKit.contains("Approval Gates"))
        #expect(launchKit.contains("License choice and formal publication/legal approval."))
        #expect(launchKit.contains("https://mediapublishing.github.io/token-monitor/"))
        #expect(launchKit.contains("https://github.com/MediaPublishing/token-monitor/blob/main/SUPPORT.md"))
        #expect(launchKit.contains("Token Monitor is not affiliated with Anthropic, OpenAI, or Apple."))
        #expect(privacy.contains("does not send usage data to Token Monitor server infrastructure"))
        #expect(privacy.contains("Provider login sessions managed by WebKit"))
        #expect(privacy.contains("Debug mode is off by default"))
        #expect(privacy.contains("GitHub Issues are public"))
    }
}
