# Apple Distribution Readiness

Last reviewed: 2026-05-02

## Objective

Prepare Token Monitor for reliable Apple distribution and growth once Apple Developer access is available.

Success means:

- Developer ID distribution can produce a signed, notarized, stapled DMG.
- Mac App Store feasibility is documented separately from direct DMG distribution.
- App Store Connect access requirements are clear before credentials are created.
- Release, support, and marketing workflows have explicit human approval gates.
- Parser/layout issues can keep moving through GitHub Issues without exposing private usage dumps.

## Current Repo State

Verified locally:

- `swift test` passes with 27 tests.
- `scripts/build-app.sh` builds `dist/TokenMonitor.app`.
- Current local build is ad hoc signed when no `TOKEN_MONITOR_CODESIGN_IDENTITY` is provided.
- `spctl --assess --type execute --verbose=4 dist/TokenMonitor.app` rejects the ad hoc build, as expected.
- `scripts/package-dmg.sh` already supports Developer ID signing and notarization through:
  - `TOKEN_MONITOR_CODESIGN_IDENTITY`
  - `TOKEN_MONITOR_NOTARIZE=1`
  - `TOKEN_MONITOR_NOTARY_PROFILE`
- `scripts/package-release.sh` already creates:
  - `dist/TokenMonitor-macOS.zip`
  - `dist/TokenMonitor-macOS.dmg`
  - `dist/appcast.xml`
  - `dist/updates/TokenMonitor-<version>-<build>-macOS.zip`
- `.github/workflows/release.yml` already publishes release assets and deploys the Sparkle appcast to GitHub Pages.

## Recommended Distribution Path

### Path A: Developer ID DMG

This is the primary path.

Why:

- It matches the current Sparkle update flow.
- It avoids Mac App Store restrictions around non-App-Store update mechanisms.
- It directly solves Gatekeeper warnings once signing and notarization are configured.
- It does not require removing Sparkle.

Required human/account setup:

- Active Apple Developer Program membership.
- Developer ID Application certificate.
- App-specific notary credentials stored locally with `xcrun notarytool store-credentials`.
- Optional GitHub Actions secrets if release signing should move to CI.

Local release command once credentials exist:

```bash
xcrun notarytool store-credentials token-monitor-notary

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh
```

Acceptance checks:

```bash
codesign --verify --deep --strict dist/TokenMonitor.app
spctl --assess --type execute --verbose=4 dist/TokenMonitor.app
xcrun stapler validate dist/TokenMonitor-macOS.dmg
```

## Mac App Store Feasibility

Mac App Store is possible only as a separate track until proven otherwise.

Known blockers or risks:

- Sparkle must be disabled or removed for the Mac App Store build because App Store apps must use App Store updates.
- App Sandbox must be enabled and tested. Token Monitor uses persistent WebKit sessions, local Application Support storage, network access, and login item registration.
- Review may question embedded WebKit login and usage-page scraping of third-party services.
- Review notes will need a clear explanation of what the app does, what data stays local, and how reviewers can test without private user accounts.
- Banking, tax, agreements, app metadata, screenshots, privacy labels, and final submission remain Account Holder / App Store Connect approval gates.

Mac App Store prep tasks:

- Add a separate MAS build configuration or script.
- Disable Sparkle and update-related settings in the MAS build.
- Add App Sandbox entitlements:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.network.client`
  - storage access limited to app container defaults where possible.
- Verify whether `SMAppService` launch-at-login works as expected under sandbox and App Review expectations.
- Prepare App Store metadata, privacy labels, screenshots, support URL, marketing URL, and review notes.
- Create a reviewer demo plan that does not require sharing private Claude or ChatGPT credentials.

## Apple Access Checklist

Do not share a personal Apple ID password in chat.

Preferred access model:

- Create a dedicated Apple ID for release operations, or invite the operator account to App Store Connect.
- Use the minimum role needed:
  - Developer for local signing/help.
  - App Manager for app metadata/submission operations.
  - Admin only if certificates/API keys/team-level access are required.
- Use App Store Connect API keys where automation is appropriate.
- Account Holder must handle or approve:
  - Developer Program enrollment.
  - Team/API key access.
  - Certificates if policy requires.
  - Paid agreements, tax, banking.
  - Final App Review submission if desired.

## Marketing Setup

Allowed to automate after approval:

- Landing page updates.
- README and GitHub Release notes.
- SEO title/description variants.
- Screenshot refreshes.
- Launch checklist.
- Newsletter/social drafts.
- Product Hunt / directory submission drafts.
- Issue triage and public support replies.

Approval gates:

- Paid ads or spend.
- Public claims about compatibility, privacy, or App Store approval.
- Public posts that mention user-provided debug data.
- Any support reply containing private usage, budget, account, or UI-dump details.

## Ongoing Issue-Fixing Loop

Current debug/reporting policy:

- Debug mode is opt-in.
- Reports open as drafts.
- GitHub Issues are public.
- Private usage dumps should not be attached unredacted.

Triage workflow:

1. Reproduce from sanitized issue text or local redacted fixture.
2. Add a focused regression test.
3. Fix parser/extraction/release logic.
4. Run `swift test`.
5. Build with `./scripts/build-app.sh`.
6. Release through GitHub if user impact is active.
7. Comment publicly with sanitized findings only.

## Source References

- Apple Developer ID: https://developer.apple.com/developer-id/
- Apple notarization docs: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Store Connect API: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
