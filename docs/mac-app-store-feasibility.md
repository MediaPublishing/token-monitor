# Mac App Store Feasibility Audit

Last reviewed: 2026-05-02

## Decision

Mac App Store distribution is not ready as-is.

The direct Developer ID DMG remains the primary path. A Mac App Store build is feasible only as a separate build track after Sparkle is removed or disabled, App Sandbox is enabled, and App Review risks around embedded provider login pages are accepted.

## Current Code Evidence

Sparkle updater:

- `Package.swift` depends on Sparkle.
- `Sources/TokenMonitorApp/AppUpdateController.swift` imports Sparkle and creates `SPUStandardUpdaterController`.
- `Sources/TokenMonitorApp/Resources/Info.plist` contains `SUFeedURL`.
- `scripts/build-app.sh` copies and signs `Sparkle.framework`.
- `scripts/package-release.sh` generates the Sparkle appcast.

Persistent WebKit sessions:

- `Sources/TokenMonitorApp/ServiceSessionController.swift` uses `WKWebsiteDataStore.default()`.
- `Sources/TokenMonitorApp/ServiceLoginWindowController.swift` opens provider login pages in `WKWebView`.

Local storage:

- `Sources/TokenMonitorApp/AppModel.swift` stores settings in `UserDefaults`.
- `Sources/TokenMonitorApp/AppModel.swift` and `Sources/TokenMonitorCore/Persistence.swift` use `Library/Application Support/TokenMonitor`.

Launch at login:

- `Sources/TokenMonitorApp/AppModel.swift` uses `SMAppService.mainApp`.
- `Sources/TokenMonitorApp/SettingsView.swift` exposes Launch at login controls and Login Items settings.

Entitlements:

- No MAS-specific entitlements file is present yet.
- No App Sandbox build path exists yet.

## Required MAS Build Changes

Before submitting to the Mac App Store:

1. Add a separate MAS build script or configuration.
2. Remove Sparkle from the MAS binary.
3. Remove `SUFeedURL` and Sparkle update UI from the MAS build.
4. Add App Sandbox entitlements.
5. Include at least:
   - `com.apple.security.app-sandbox`
   - `com.apple.security.network.client`
6. Verify Application Support and WebKit storage work inside the app container.
7. Verify `SMAppService` launch-at-login behavior under sandbox.
8. Prepare reviewer notes explaining embedded WebKit sessions and local-only storage.
9. Provide reviewer accounts or a reviewer test plan.

## App Review Risks

High-risk items:

- The app displays usage data from third-party provider account pages.
- Review may reject or question scraping or parsing provider web layouts.
- Reviewer testing requires access to Claude, ChatGPT, and Codex usage pages.
- App Store apps cannot use Sparkle for updates.

Medium-risk items:

- Embedded WebKit login pages may require clear explanation.
- Provider UI changes can temporarily break parsing.
- Login Items behavior may need extra reviewer guidance.

Low-risk items:

- Local `UserDefaults` settings.
- Local Application Support snapshots, if sandboxed correctly.
- Menu bar UI and read-only dashboard behavior.

## Go Criteria

Proceed with MAS implementation only if all are true:

- Account Holder approves Mac App Store submission work.
- Apple Developer access is available.
- The team accepts review risk around provider usage-page parsing.
- A separate MAS build can be maintained without breaking direct DMG releases.
- Privacy labels and review notes receive human approval.

## No-Go Criteria

Keep Developer ID DMG only if any are true:

- Sparkle updates are required for the same build.
- Reviewer test accounts cannot be provided.
- The provider-page parsing behavior is considered too risky for App Review.
- The team does not want to maintain separate direct-DMG and MAS builds.

## Recommended Next Step

After Developer ID distribution is working, revisit MAS with a small proof-of-concept branch:

1. Add `scripts/build-mas-app.sh`.
2. Add `Sources/TokenMonitorApp/Resources/TokenMonitorMAS.entitlements`.
3. Compile a MAS build without Sparkle.
4. Run a sandbox smoke test for login, refresh, snapshots, and Login Items.
5. Decide whether to continue toward App Store Connect submission.
