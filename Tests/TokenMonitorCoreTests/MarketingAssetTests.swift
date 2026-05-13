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
        let ciWorkflow = try String(
            contentsOf: rootURL.appendingPathComponent(".github/workflows/ci.yml"),
            encoding: .utf8
        )
        let publicReleaseVerifierURL = rootURL.appendingPathComponent("scripts/verify-public-release.sh")
        let publicReleaseVerifier = try String(contentsOf: publicReleaseVerifierURL, encoding: .utf8)

        let dmgScriptURL = rootURL.appendingPathComponent("scripts/package-dmg.sh")
        let releasePackageScriptURL = rootURL.appendingPathComponent("scripts/package-release.sh")
        let releasePackageScript = try String(contentsOf: releasePackageScriptURL, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: dmgScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: dmgScriptURL.path))
        #expect(FileManager.default.fileExists(atPath: releasePackageScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: releasePackageScriptURL.path))
        #expect(FileManager.default.fileExists(atPath: publicReleaseVerifierURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: publicReleaseVerifierURL.path))
        #expect(readme.contains("TokenMonitor-macOS.dmg"))
        #expect(readme.contains("Gatekeeper"))
        #expect(readme.contains("notarized"))
        #expect(readme.contains("Open Anyway"))
        #expect(readme.contains("Dennoch öffnen"))
        #expect(readme.contains("Launch at login"))
        #expect(readme.contains("Automatic update checks are off by default from version `1.0.22`"))
        #expect(readme.contains("Automatische Update-Prüfungen sind ab Version `1.0.22` standardmäßig aus"))
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
        #expect(landingHTML.contains("automatic update checks are off by default"))
        #expect(landingHTML.contains("automatische Update-Prüfungen standardmäßig aus"))
        #expect(!landingHTML.contains("Would a PKG avoid"))
        #expect(!landingHTML.contains("How do updates work?"))
        let dmgScript = try String(contentsOf: dmgScriptURL, encoding: .utf8)
        #expect(dmgScript.contains("Notarization requires a signed Developer ID build."))
        #expect(dmgScript.contains("Notarization requires a Developer ID Application identity."))
        #expect(dmgScript.contains("Developer\\ ID\\ Application:*"))
        #expect(dmgScript.contains("TOKEN_MONITOR_CODESIGN_IDENTITY"))
        #expect(dmgScript.contains("codesign --verify --strict \"$DMG_PATH\""))
        #expect(dmgScript.contains("xcrun stapler validate \"$DMG_PATH\""))
        #expect(releaseWorkflow.contains("workflow_dispatch"))
        #expect(releaseWorkflow.contains("require_developer_id"))
        #expect(releaseWorkflow.contains("allow_unsigned_preview"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_REQUIRE_DEVELOPER_ID"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_RELEASE_IS_PRERELEASE"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_ALLOW_UNSIGNED_PREVIEW"))
        #expect(releaseWorkflow.contains("RELEASE_TAG:"))
        #expect(releaseWorkflow.contains("github.event.inputs.tag"))
        #expect(releaseWorkflow.contains("Restore current release tooling"))
        #expect(releaseWorkflow.contains("git checkout origin/main --"))
        #expect(releaseWorkflow.contains("scripts/package-release.sh"))
        #expect(releaseWorkflow.contains("scripts/check-github-release-channel.sh"))
        #expect(releaseWorkflow.contains("package-release.sh"))
        #expect(releaseWorkflow.contains("package_args+=(--require-distribution-ready)"))
        #expect(releaseWorkflow.contains("dist/TokenMonitor-macOS.dmg"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_CODESIGN_IDENTITY"))
        #expect(releaseWorkflow.contains("Developer\\ ID\\ Application:*"))
        #expect(releaseWorkflow.contains("must start with 'Developer ID Application:'"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_NOTARY_APP_PASSWORD"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_NOTARIZE=1"))
        #expect(releaseWorkflow.contains("Developer ID signing is not configured; skipping notarization."))
        #expect(releaseWorkflow.contains("Refusing to upload a signed non-notarized release."))
        #expect(releaseWorkflow.contains("Unsigned release artifacts require a GitHub prerelease or allow_unsigned_preview=true."))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_RELEASE_NOTES_PATH"))
        #expect(releaseWorkflow.contains("gh release view \"$RELEASE_TAG\" --json body"))
        #expect(releaseWorkflow.contains("landing/index.html"))
        #expect(releaseWorkflow.contains("Check release version consistency"))
        #expect(releaseWorkflow.contains("./scripts/check-release-version-consistency.sh --tag \"$RELEASE_TAG\" --require-tag"))
        #expect(releaseWorkflow.contains("Check public repository hygiene"))
        #expect(releaseWorkflow.contains("./scripts/check-public-repo-hygiene.sh"))
        #expect(releaseWorkflow.contains("Check Apple access handoff"))
        #expect(releaseWorkflow.contains("vars.TOKEN_MONITOR_APPLE_TEAM_ID"))
        #expect(releaseWorkflow.contains("./scripts/check-apple-access-handoff.sh --require-direct-dmg-access"))
        #expect(releaseWorkflow.contains("Check GitHub release channel"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_PUBLIC_RELEASE_TAG: ${{ env.RELEASE_TAG }}"))
        #expect(releaseWorkflow.contains("TOKEN_MONITOR_ALLOW_STABLE_RELEASES=1 ./scripts/check-github-release-channel.sh"))
        #expect(ciWorkflow.contains("Check release scripts"))
        #expect(ciWorkflow.contains("bash -n scripts/*.sh"))
        #expect(ciWorkflow.contains("./scripts/check-apple-access-handoff.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-github-release-variables.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-app-store-metadata.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-app-store-screenshots.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-app-store-identity.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-release-recovery-readiness.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-release-version-consistency.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-public-repo-hygiene.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-release-version-consistency.sh"))
        #expect(ciWorkflow.contains("./scripts/check-public-repo-hygiene.sh"))
        #expect(ciWorkflow.contains("./scripts/check-publication-legal-gates.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-app-store-metadata.sh"))
        #expect(ciWorkflow.contains("./scripts/audit-apple-distribution.sh --help"))
        #expect(ciWorkflow.contains("./scripts/package-mas-pkg.sh --help"))
        #expect(ciWorkflow.contains("./scripts/check-app-store-upload-readiness.sh --help"))
        #expect(ciWorkflow.contains("Missing TOKEN_MONITOR_MAS_CODESIGN_IDENTITY"))
        #expect(publicReleaseVerifier.contains("TokenMonitor-macOS.dmg"))
        #expect(publicReleaseVerifier.contains("TokenMonitor-macOS.zip"))
        #expect(publicReleaseVerifier.contains("appcast.xml"))
        #expect(publicReleaseVerifier.contains("TAG\" == \"-h\" || \"$TAG\" == \"--help\""))
        #expect(publicReleaseVerifier.contains("updates/$UPDATE_ZIP_NAME"))
        #expect(publicReleaseVerifier.contains("TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1"))
        #expect(publicReleaseVerifier.contains("public DMG, GitHub ZIP, and Sparkle update ZIP"))
        #expect(publicReleaseVerifier.contains("spctl --assess --type open"))
        #expect(publicReleaseVerifier.contains("xcrun stapler validate"))
        #expect(publicReleaseVerifier.contains("verify_downloaded_zip \"GitHub ZIP\""))
        #expect(publicReleaseVerifier.contains("verify_downloaded_zip \"Sparkle update ZIP\""))
        #expect(publicReleaseVerifier.contains("Downloaded $label app code signature verifies"))
        #expect(publicReleaseVerifier.contains("Downloaded $label app version matches"))
        #expect(publicReleaseVerifier.contains("dist/public-release-verification"))
        #expect(releasePackageScript.contains("--require-distribution-ready"))
        #expect(releasePackageScript.contains("TOKEN_MONITOR_REQUIRE_DISTRIBUTION_READY"))
        #expect(releasePackageScript.contains("scripts/check-apple-distribution.sh\" --require-ready"))
        #expect(releasePackageScript.contains("verify_release_zip \"GitHub release ZIP\""))
        #expect(releasePackageScript.contains("verify_release_zip \"Sparkle update ZIP\""))
        #expect(releasePackageScript.contains("TOKEN_MONITOR_RELEASE_NOTES_PATH"))
        #expect(releasePackageScript.contains("--embed-release-notes"))
        #expect(releasePackageScript.contains("VERSIONED_RELEASE_NOTES_PATH"))
        #expect(releasePackageScript.contains("did not contain TokenMonitor.app"))
        #expect(releasePackageScript.contains("version mismatch"))
        #expect(releasePackageScript.contains("Verified %s %s contains signed TokenMonitor.app"))
        #expect(releasePackageScript.contains("scripts/check-apple-distribution.sh\" --require-ready"))
    }

    @Test func appleDistributionReadinessDocCoversReleasePaths() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let requiredFiles = [
            "docs/apple-distribution-readiness.md",
            "docs/apple-access-handoff.md",
            "docs/apple-distribution-completion-audit.md",
            "docs/apple-credential-runbook.md",
            "docs/mac-app-store-feasibility.md",
            "packaging/TokenMonitorMAS.entitlements",
            "docs/app-store-connect-identity.md",
            "docs/app-store-review-risk-register.md",
            "docs/release-recovery-runbook.md",
            "docs/issue-triage-runbook.md",
            "docs/publication-legal-checklist.md",
            "docs/app-store-submission-packet.md",
            "docs/app-store-privacy-labels.md",
            "docs/app-store-screenshot-checklist.md",
            "docs/mas-sandbox-smoke-test.md",
            "docs/mas-sandbox-smoke-test-receipt.md",
            "scripts/check-apple-access-handoff.sh",
            "scripts/check-apple-distribution.sh",
            "scripts/check-github-release-variables.sh",
            "scripts/check-github-release-secrets.sh",
            "scripts/check-github-release-channel.sh",
            "scripts/check-github-issue-labels.sh",
            "scripts/check-github-security-reporting.sh",
            "scripts/check-app-store-metadata.sh",
            "scripts/check-app-store-screenshots.sh",
            "scripts/check-app-store-identity.sh",
            "scripts/check-release-recovery-readiness.sh",
            "scripts/check-release-version-consistency.sh",
            "scripts/audit-apple-distribution.sh",
            "scripts/preflight-release.sh",
            "scripts/check-mas-readiness.sh",
            "scripts/verify-mas-build.sh",
            "scripts/package-mas-pkg.sh",
            "scripts/preflight-mas-submission.sh",
            "scripts/check-app-store-upload-readiness.sh",
            "scripts/check-app-store-submission-gates.sh",
            "scripts/check-publication-legal-gates.sh",
            "scripts/check-public-repo-hygiene.sh",
            "Sources/TokenMonitorApp/SettingsView.swift",
            "Sources/TokenMonitorApp/AppUpdateController.swift"
        ]
        let missingFiles = requiredFiles.filter { path in
            !FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(path).path)
        }
        #expect(missingFiles.isEmpty, "Missing distribution readiness files: \(missingFiles)")

        let executableScripts = requiredFiles.filter { $0.hasPrefix("scripts/") }
        let nonExecutableScripts = executableScripts.filter { path in
            !FileManager.default.isExecutableFile(atPath: rootURL.appendingPathComponent(path).path)
        }
        #expect(nonExecutableScripts.isEmpty, "Distribution scripts are not executable: \(nonExecutableScripts)")

        let coverage: [(String, [String])] = [
            ("README.md", [
                "docs/apple-distribution-readiness.md",
                "docs/apple-access-handoff.md",
                "docs/apple-credential-runbook.md",
                "docs/mac-app-store-feasibility.md",
                "docs/app-store-submission-packet.md",
                "docs/app-store-review-risk-register.md",
                "docs/app-store-connect-identity.md",
                "docs/app-store-privacy-labels.md",
                "docs/app-store-screenshot-checklist.md",
                "docs/release-recovery-runbook.md",
                "docs/issue-triage-runbook.md",
                "docs/publication-legal-checklist.md"
            ]),
            ("docs/apple-distribution-readiness.md", [
                "Developer ID DMG",
                "Mac App Store Feasibility",
                "TOKEN_MONITOR_CODESIGN_IDENTITY",
                "TOKEN_MONITOR_NOTARIZE",
                "TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64",
                "TOKEN_MONITOR_NOTARY_APP_PASSWORD",
                "App Store Connect API",
                "SPARKLE_PRIVATE_KEY",
                "Public distribution URL checker",
                "Apple access handoff checker",
                "GitHub release variable checker",
                "preview-only",
                "Marketing Setup",
                "Ongoing Issue-Fixing Loop",
                "docs/issue-triage-runbook.md",
                "Completion Audit",
                "not complete until a signed, notarized, stapled Developer ID release is produced"
            ]),
            ("docs/apple-distribution-completion-audit.md", [
                "Prompt-To-Artifact Checklist",
                "./scripts/audit-apple-distribution.sh --require-complete",
                "./scripts/check-apple-access-handoff.sh --require-direct-dmg-access",
                "./scripts/check-github-release-variables.sh --require-direct-dmg-variables",
                "./scripts/preflight-release.sh --require-signing-secrets --require-apple-access-handoff",
                "./scripts/check-app-store-metadata.sh",
                "./scripts/check-app-store-identity.sh --require-ready",
                "./scripts/check-release-recovery-readiness.sh --require-ready",
                "./scripts/check-release-version-consistency.sh",
                "./scripts/check-public-repo-hygiene.sh",
                "./scripts/check-github-security-reporting.sh --require-private-vulnerability-reporting",
                "./scripts/check-public-distribution-urls.sh",
                "./scripts/check-apple-access-handoff.sh",
                "./scripts/check-github-release-variables.sh",
                "./scripts/check-github-issue-labels.sh",
                "docs/app-store-review-risk-register.md",
                "docs/issue-triage-runbook.md",
                "preview-only",
                "Not complete.",
                "Do not mark the Apple distribution objective complete",
                "Apple Distribution certificate",
                "Mac App Store installer distribution certificate",
                "dist/mas/TokenMonitor-macOS-AppStore.pkg",
                "./scripts/check-app-store-upload-readiness.sh --require-ready",
                "./scripts/check-publication-legal-gates.sh --require-legal-gates"
            ]),
            ("docs/apple-credential-runbook.md", [
                "./scripts/check-apple-access-handoff.sh --require-direct-dmg-access",
                "./scripts/check-github-release-variables.sh --require-direct-dmg-variables",
                "TOKEN_MONITOR_ALLOW_UNSIGNED_PREVIEW_RELEASES=1",
                "TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64",
                "TOKEN_MONITOR_NOTARY_APP_PASSWORD",
                "SPARKLE_PRIVATE_KEY",
                "./scripts/audit-apple-distribution.sh --require-complete --run-tests",
                "./scripts/preflight-release.sh --require-signing-secrets --require-apple-access-handoff",
                "./scripts/package-release.sh --require-distribution-ready",
                "TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1",
                "Mac App Store Certificates",
                "App Store Connect Upload Credentials"
            ]),
            ("docs/mac-app-store-feasibility.md", [
                "Mac App Store distribution is not ready as-is.",
                "./scripts/check-mas-readiness.sh",
                "docs/app-store-review-risk-register.md",
                "scripts/check-app-store-identity.sh --require-ready",
                "scripts/package-mas-pkg.sh",
                "scripts/check-app-store-upload-readiness.sh",
                "com.apple.security.app-sandbox"
            ]),
            ("docs/app-store-submission-packet.md", [
                "Reviewer Notes Draft",
                "Reviewer Test Plan",
                "Privacy Label Draft",
                "./scripts/check-app-store-metadata.sh",
                "./scripts/check-app-store-screenshots.sh --require-ready",
                "scripts/check-app-store-submission-gates.sh --require-human-gates",
                "docs/app-store-review-risk-register.md",
                "No Sparkle framework or `SU*` Info.plist keys"
            ]),
            ("docs/app-store-review-risk-register.md", [
                "Embedded provider login pages",
                "Third-party usage-page parsing",
                "No hosted account service",
                "Sparkle in App Store build",
                "App Sandbox behavior",
                "Reviewer account access",
                "Privacy labels",
                "Debug reporting",
                "Launch at Login",
                "Draft Response Snippets",
                "If App Review Rejects",
                "./scripts/check-app-store-submission-gates.sh --require-human-gates",
                "./scripts/check-publication-legal-gates.sh --require-legal-gates"
            ]),
            ("docs/apple-access-handoff.md", [
                "./scripts/check-github-release-secrets.sh --require-signing-secrets",
                "./scripts/preflight-release.sh --require-signing-secrets --require-apple-access-handoff"
            ]),
            ("docs/release-recovery-runbook.md", [
                "./scripts/preflight-release.sh --require-signing-secrets --require-apple-access-handoff --require-distribution-ready"
            ]),
            ("docs/app-store-privacy-labels.md", [
                "No, Token Monitor does not collect data from this app.",
                "No, Token Monitor does not track users across apps or websites.",
                "TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED=1"
            ]),
            ("docs/app-store-screenshot-checklist.md", [
                "1 to 10 screenshots",
                "16:10 aspect ratio",
                "1280 x 800",
                "2880 x 1800",
                "TOKEN_MONITOR_APP_STORE_SCREENSHOTS_APPROVED=1"
            ]),
            ("docs/mas-sandbox-smoke-test.md", [
                "Pass Criteria",
                "Fail Conditions",
                "Launch at Login",
                "Debug GitHub draft",
                "Debug email draft"
            ]),
            ("docs/issue-triage-runbook.md", [
                "Public Issue Rules",
                "Intake Checklist",
                "Parser/Layout Bugs",
                "Install, Gatekeeper, And Update Bugs",
                "Public Reply Template",
                "Private Report Redirect Template",
                "Hotfix Release Path",
                "Closeout Checklist",
                "GitHub Label Setup",
                "./scripts/check-github-issue-labels.sh",
                ".github/ISSUE_TEMPLATE/parser-layout-bug.yml",
                ".github/ISSUE_TEMPLATE/install-update-bug.yml",
                "./scripts/check-public-distribution-urls.sh",
                "./scripts/check-github-release-channel.sh",
                "TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1"
            ]),
            ("scripts/check-github-issue-labels.sh", [
                "parser",
                "install",
                "needs-triage",
                "Issue templates reference label"
            ]),
            ("scripts/audit-apple-distribution.sh", [
                "--require-complete",
                "./scripts/check-apple-access-handoff.sh",
                "./scripts/check-github-release-variables.sh",
                "./scripts/check-release-version-consistency.sh",
                "./scripts/check-public-repo-hygiene.sh",
                "./scripts/check-github-release-channel.sh",
                "./scripts/check-github-security-reporting.sh",
                "./scripts/check-app-store-metadata.sh",
                "./scripts/check-app-store-screenshots.sh --require-ready",
                "./scripts/check-app-store-identity.sh --require-ready",
                "./scripts/check-github-release-secrets.sh --require-signing-secrets",
                "./scripts/check-apple-distribution.sh --require-ready",
                "./scripts/check-app-store-upload-readiness.sh --require-ready",
                "./scripts/check-app-store-submission-gates.sh --require-human-gates",
                "./scripts/check-publication-legal-gates.sh --require-legal-gates",
                "./scripts/check-release-recovery-readiness.sh --require-ready"
            ]),
            ("scripts/preflight-release.sh", [
                "swift test",
                "./scripts/check-release-version-consistency.sh",
                "./scripts/check-public-repo-hygiene.sh",
                "--require-apple-access-handoff",
                "./scripts/check-apple-access-handoff.sh --require-direct-dmg-access",
                "./scripts/check-github-release-variables.sh --require-direct-dmg-variables",
                "./scripts/check-github-release-secrets.sh --require-signing-secrets",
                "./scripts/check-apple-distribution.sh --require-ready"
            ]),
            ("scripts/package-mas-pkg.sh", [
                "TOKEN_MONITOR_MAS_INSTALLER_IDENTITY",
                "productbuild",
                "TokenMonitor-macOS-AppStore.pkg",
                "verify-mas-build.sh\" --require-apple-distribution"
            ]),
            ("scripts/preflight-mas-submission.sh", [
                "TOKEN_MONITOR_MAS_CODESIGN_IDENTITY",
                "TOKEN_MONITOR_MAS_INSTALLER_IDENTITY",
                "./scripts/check-app-store-identity.sh --require-ready",
                "./scripts/verify-mas-build.sh --require-apple-distribution",
                "./scripts/package-mas-pkg.sh"
            ])
        ]

        let missingCoverage = try coverage.flatMap { path, needles -> [String] in
            let text = try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
            return needles.filter { !text.contains($0) }.map { "\(path): \($0)" }
        }
        #expect(missingCoverage.isEmpty, "Missing distribution readiness coverage: \(missingCoverage)")
    }

    @Test func publicDistributionURLChecksAreCovered() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let publicDistributionURLsScriptURL = rootURL.appendingPathComponent("scripts/check-public-distribution-urls.sh")
        let releaseChannelScriptURL = rootURL.appendingPathComponent("scripts/check-github-release-channel.sh")
        let publicDistributionURLsScript = try String(contentsOf: publicDistributionURLsScriptURL, encoding: .utf8)
        let releaseChannelScript = try String(contentsOf: releaseChannelScriptURL, encoding: .utf8)
        let distributionAuditScript = try String(
            contentsOf: rootURL.appendingPathComponent("scripts/audit-apple-distribution.sh"),
            encoding: .utf8
        )
        let completionAudit = try String(
            contentsOf: rootURL.appendingPathComponent("docs/apple-distribution-completion-audit.md"),
            encoding: .utf8
        )
        let launchKit = try String(
            contentsOf: rootURL.appendingPathComponent("docs/marketing-launch-kit.md"),
            encoding: .utf8
        )

        #expect(FileManager.default.fileExists(atPath: publicDistributionURLsScriptURL.path))
        #expect(FileManager.default.fileExists(atPath: releaseChannelScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: publicDistributionURLsScriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: releaseChannelScriptURL.path))
        #expect(publicDistributionURLsScript.contains("Support URL"))
        #expect(publicDistributionURLsScript.contains("Marketing URL"))
        #expect(publicDistributionURLsScript.contains("Privacy URL"))
        #expect(publicDistributionURLsScript.contains("Public release page"))
        #expect(publicDistributionURLsScript.contains("Public DMG download URL"))
        #expect(publicDistributionURLsScript.contains("TOKEN_MONITOR_PUBLIC_RELEASE_TAG"))
        #expect(publicDistributionURLsScript.contains("Security reporting URL"))
        #expect(publicDistributionURLsScript.contains("TOKEN_MONITOR_APP_STORE_PACKET"))
        #expect(releaseChannelScript.contains("TOKEN_MONITOR_PUBLIC_RELEASE_TAG"))
        #expect(releaseChannelScript.contains("TOKEN_MONITOR_ALLOW_STABLE_RELEASES"))
        #expect(releaseChannelScript.contains("--exclude-pre-releases"))
        #expect(releaseChannelScript.contains("must be a prerelease until Developer ID signing is available"))
        #expect(distributionAuditScript.contains("./scripts/check-public-distribution-urls.sh"))
        #expect(distributionAuditScript.contains("./scripts/check-github-release-channel.sh"))
        #expect(completionAudit.contains("Check public distribution URLs"))
        #expect(completionAudit.contains("./scripts/check-public-distribution-urls.sh"))
        #expect(launchKit.contains("./scripts/check-public-distribution-urls.sh"))
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
        let installIssueTemplateURL = rootURL.appendingPathComponent(".github/ISSUE_TEMPLATE/install-update-bug.yml")
        let issueConfigURL = rootURL.appendingPathComponent(".github/ISSUE_TEMPLATE/config.yml")
        let parserIssueTemplate = try String(contentsOf: parserIssueTemplateURL, encoding: .utf8)
        let installIssueTemplate = try String(contentsOf: installIssueTemplateURL, encoding: .utf8)
        let issueConfig = try String(contentsOf: issueConfigURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: parserIssueTemplateURL.path))
        #expect(FileManager.default.fileExists(atPath: installIssueTemplateURL.path))
        #expect(FileManager.default.fileExists(atPath: issueConfigURL.path))
        #expect(distributionDoc.contains(".github/ISSUE_TEMPLATE/parser-layout-bug.yml"))
        #expect(distributionDoc.contains(".github/ISSUE_TEMPLATE/install-update-bug.yml"))
        #expect(parserIssueTemplate.contains("GitHub Issues are public"))
        #expect(parserIssueTemplate.contains("Do not attach raw debug dumps"))
        #expect(parserIssueTemplate.contains("chat titles"))
        #expect(parserIssueTemplate.contains("usage budgets"))
        #expect(parserIssueTemplate.contains("Token Monitor version"))
        #expect(parserIssueTemplate.contains("Account language or locale"))
        #expect(parserIssueTemplate.contains("Privacy check"))
        #expect(installIssueTemplate.contains("GitHub Issues are public"))
        #expect(installIssueTemplate.contains("Apple ID passwords"))
        #expect(installIssueTemplate.contains("GitHub Secrets"))
        #expect(installIssueTemplate.contains("Gatekeeper"))
        #expect(installIssueTemplate.contains("Sparkle update"))
        #expect(installIssueTemplate.contains("Launch at Login"))
        #expect(installIssueTemplate.contains("Privacy check"))
        #expect(issueConfig.contains("blank_issues_enabled: false"))
        #expect(!parserIssueTemplate.contains("info@etraininghq.com"))
        #expect(!installIssueTemplate.contains("info@etraininghq.com"))
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
        #expect(support.contains("install-update-bug.yml"))
        #expect(support.contains("parser-layout-bug.yml"))
        #expect(support.contains("docs/privacy.md"))
        #expect(support.contains("SECURITY.md"))
        #expect(support.contains("Apple ID passwords"))
        #expect(support.contains("GitHub private vulnerability reporting"))
        #expect(!support.contains("if available"))
        #expect(!support.contains("info@etraininghq.com"))
        #expect(security.contains("Reporting A Vulnerability"))
        #expect(security.contains("Do not open a public issue"))
        #expect(security.contains("GitHub private vulnerability reporting"))
        #expect(!security.contains("if it is available"))
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
        #expect(launchKit.contains("docs/app-store-review-risk-register.md"))
        #expect(launchKit.contains("Screenshot Inventory"))
        #expect(launchKit.contains("docs/app-store-screenshot-checklist.md"))
        #expect(launchKit.contains("Launch Checklist"))
        #expect(launchKit.contains("./scripts/check-github-release-secrets.sh --require-signing-secrets"))
        #expect(launchKit.contains("./scripts/check-apple-access-handoff.sh --require-direct-dmg-access"))
        #expect(launchKit.contains("./scripts/check-github-release-variables.sh --require-direct-dmg-variables"))
        #expect(launchKit.contains("./scripts/preflight-release.sh --require-signing-secrets --require-apple-access-handoff"))
        #expect(launchKit.contains("./scripts/check-release-version-consistency.sh --tag <tag> --require-tag"))
        #expect(launchKit.contains("./scripts/check-public-repo-hygiene.sh"))
        #expect(launchKit.contains("./scripts/package-release.sh --require-distribution-ready"))
        #expect(launchKit.contains("./scripts/package-mas-pkg.sh"))
        #expect(launchKit.contains("./scripts/check-app-store-metadata.sh"))
        #expect(launchKit.contains("./scripts/check-app-store-screenshots.sh --require-ready"))
        #expect(launchKit.contains("./scripts/check-app-store-identity.sh --require-ready"))
        #expect(launchKit.contains("./scripts/check-app-store-upload-readiness.sh --require-ready"))
        #expect(launchKit.contains("./scripts/check-app-store-submission-gates.sh --require-human-gates"))
        #expect(launchKit.contains("./scripts/check-publication-legal-gates.sh --require-legal-gates"))
        #expect(launchKit.contains("./scripts/check-release-recovery-readiness.sh --require-ready"))
        #expect(launchKit.contains("Gatekeeper, stapler, GitHub release ZIP, and Sparkle update ZIP checks"))
        #expect(launchKit.contains("./scripts/verify-public-release.sh <tag> <version> <build>"))
        #expect(launchKit.contains("TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1"))
        #expect(launchKit.contains("published DMG, GitHub release ZIP, and Sparkle update ZIP"))
        #expect(launchKit.contains("Approval Gates"))
        #expect(launchKit.contains("License choice and formal publication/legal approval."))
        #expect(launchKit.contains("https://mediapublishing.github.io/token-monitor/"))
        #expect(launchKit.contains("https://github.com/MediaPublishing/token-monitor/blob/main/SUPPORT.md"))
        #expect(launchKit.contains("Token Monitor is not affiliated with Anthropic, OpenAI, or Apple."))
        #expect(privacy.contains("does not send usage data to Token Monitor server infrastructure"))
        #expect(privacy.contains("Provider login sessions managed by WebKit"))
        #expect(privacy.contains("Debug mode is off by default"))
        #expect(privacy.contains("GitHub Issues are public"))
        #expect(privacy.contains("docs/app-store-privacy-labels.md"))
    }
}
