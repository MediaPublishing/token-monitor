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

- `swift test` passes with 30 tests.
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
- `.github/workflows/release.yml` publishes release assets, deploys the Sparkle appcast to GitHub Pages, and can import Developer ID/notary credentials from GitHub Secrets when they are available.

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

GitHub Actions secrets for signed/notarized releases:

- `TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` Developer ID Application certificate.
- `TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` certificate.
- `TOKEN_MONITOR_CODESIGN_IDENTITY`: exact certificate identity, for example `Developer ID Application: <Name> (<TEAMID>)`.
- `TOKEN_MONITOR_RELEASE_KEYCHAIN_PASSWORD`: optional temporary CI keychain password.
- `TOKEN_MONITOR_NOTARY_APPLE_ID`: Apple ID used for notarization.
- `TOKEN_MONITOR_NOTARY_TEAM_ID`: Apple Developer Team ID.
- `TOKEN_MONITOR_NOTARY_APP_PASSWORD`: app-specific password for notarization.

Credential setup details live in `docs/apple-credential-runbook.md`.

Local release command once credentials exist:

```bash
xcrun notarytool store-credentials token-monitor-notary

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh
```

Local readiness check:

```bash
./scripts/check-apple-distribution.sh

TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
./scripts/check-apple-distribution.sh
```

The readiness check is advisory. It reports missing certificates, missing notary credentials, ad hoc signatures, and unstapled DMGs as warnings so the repo remains usable before Apple Developer access exists.

Acceptance checks:

```bash
codesign --verify --deep --strict dist/TokenMonitor.app
spctl --assess --type execute --verbose=4 dist/TokenMonitor.app
xcrun stapler validate dist/TokenMonitor-macOS.dmg
```

## Mac App Store Feasibility

Mac App Store is possible only as a separate track until proven otherwise.

Detailed current-state audit: `docs/mac-app-store-feasibility.md`.

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

Operational launch copy and App Store draft metadata live in `docs/marketing-launch-kit.md`.

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
- Public parser reports should use `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`.
- Private usage dumps should not be attached unredacted.

Triage workflow:

1. Reproduce from sanitized issue text or local redacted fixture.
2. Add a focused regression test.
3. Fix parser/extraction/release logic.
4. Run `swift test`.
5. Build with `./scripts/build-app.sh`.
6. Release through GitHub if user impact is active.
7. Comment publicly with sanitized findings only.

## Completion Audit

Prepared and verified repo artifacts:

- App release behavior: `v1.0.14` / build `15` includes the remaining-quota progress bar fix.
- Direct Developer ID distribution docs: `docs/apple-distribution-readiness.md`.
- Apple credential setup: `docs/apple-credential-runbook.md`.
- Local signing/notarization verifier: `scripts/check-apple-distribution.sh`.
- GitHub signed release workflow: `.github/workflows/release.yml`.
- Mac App Store feasibility audit: `docs/mac-app-store-feasibility.md`.
- Marketing and App Store draft metadata: `docs/marketing-launch-kit.md`.
- Public privacy summary: `docs/privacy.md`.
- Public parser issue form with privacy warnings: `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`.
- Regression coverage: `swift test` passes with 30 tests.

Current blockers:

- No Developer ID Application certificate is installed locally.
- No local `TOKEN_MONITOR_NOTARY_PROFILE` is configured.
- The local app bundle is ad hoc signed.
- Gatekeeper rejects the current local app and DMG.
- The current DMG has no stapled notarization ticket.
- GitHub release signing secrets are documented but not configured with real Apple credentials.
- Mac App Store submission remains a separate, not-ready track until Sparkle is removed from a MAS build and sandboxing is tested.

Conclusion:

- The repository is prepared for Apple Developer access.
- The objective is not complete until a signed, notarized, stapled Developer ID release is produced and verified with real Apple credentials.

## Source References

- Apple Developer ID: https://developer.apple.com/developer-id/
- Apple notarization docs: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Store Connect API: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
