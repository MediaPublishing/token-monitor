# Apple Distribution Readiness

Last reviewed: 2026-05-13

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

- `swift test` passes with 34 tests.
- `scripts/build-app.sh` builds `dist/TokenMonitor.app`.
- Current local direct-DMG build is `1.0.20` build `21` and is ad hoc signed when no `TOKEN_MONITOR_CODESIGN_IDENTITY` is provided.
- Verified 2026-05-12: `spctl --assess --type execute --verbose=4 dist/TokenMonitor.app` rejects the ad hoc build, as expected.
- Verified 2026-05-12: `spctl` rejects `dist/TokenMonitor-macOS.dmg` because it has no usable signature, and `xcrun stapler validate` reports no stapled ticket.
- Verified 2026-05-12: GitHub repository `MediaPublishing/token-monitor` is public.
- Verified 2026-05-12: GitHub Release `v1.0.20` is published and includes `TokenMonitor-macOS.dmg` and `TokenMonitor-macOS.zip`.
- Verified 2026-05-12: no open GitHub PRs or Issues were present.
- `scripts/package-dmg.sh` already supports Developer ID signing and notarization through:
  - `TOKEN_MONITOR_CODESIGN_IDENTITY`
  - `TOKEN_MONITOR_NOTARIZE=1`
  - `TOKEN_MONITOR_NOTARY_PROFILE`
- `scripts/package-release.sh` already creates:
  - `dist/TokenMonitor-macOS.zip`
  - `dist/TokenMonitor-macOS.dmg`
  - `dist/appcast.xml`
  - `dist/updates/TokenMonitor-<version>-<build>-macOS.zip`
- `scripts/preflight-release.sh` runs the local release readiness checks in operator order before publishing or republishing assets.
- `.github/workflows/release.yml` publishes release assets, deploys the Sparkle appcast to GitHub Pages, and can import Developer ID/notary credentials from GitHub Secrets when they are available.
- The release workflow can also be run manually with an existing tag through `workflow_dispatch` to rebuild and republish release assets, the appcast, and GitHub Pages without creating a new version.
- The manual release workflow has a `require_developer_id` option. When enabled, the workflow fails before upload unless Developer ID signing and notarization are configured and verified.
- The release workflow refuses to upload a signed non-notarized release if Developer ID signing secrets exist but notary secrets are incomplete.
- `scripts/package-release.sh --require-distribution-ready` verifies the final app, DMG, notarization ticket, GitHub release ZIP, and versioned Sparkle update ZIP before upload.
- `scripts/verify-public-release.sh` can verify the public DMG, GitHub release ZIP, and public Sparkle update ZIP together when `TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1` is set.
- `scripts/audit-apple-distribution.sh` provides a safe consolidated audit command; use `--require-complete --run-tests` only after Apple credentials and human approvals exist.
- `scripts/build-mas-app.sh` produces a separate `1.0.20` build `21` MAS candidate.
- `scripts/verify-mas-build.sh` verifies the MAS candidate has no Sparkle files, no Sparkle binary link, no `SU*` update keys, sandbox/network entitlements, and a valid local signature. Use `--require-apple-distribution` before App Store submission.
- `scripts/package-mas-pkg.sh` packages the Apple Distribution signed MAS app as `dist/mas/TokenMonitor-macOS-AppStore.pkg` with a Mac App Store installer distribution identity.
- `scripts/check-app-store-upload-readiness.sh` checks the final upload handoff without uploading anything: signed package presence, local upload tool availability, and approved upload authentication inputs.

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
./scripts/package-release.sh --require-distribution-ready
```

Local readiness check:

```bash
./scripts/check-apple-distribution.sh

TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
./scripts/check-apple-distribution.sh

TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
./scripts/check-apple-distribution.sh --require-ready
```

The readiness check is advisory by default. It reports missing certificates, missing notary credentials, ad hoc signatures, and unstapled DMGs as warnings so the repo remains usable before Apple Developer access exists. Use `--require-ready` after Developer ID credentials are configured to make any signing, Gatekeeper, or notarization warning fail the check.

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

- Sparkle is disabled in the draft Mac App Store build path because App Store apps must use App Store updates.
- App Sandbox must be enabled and tested. Token Monitor uses persistent WebKit sessions, local Application Support storage, network access, and login item registration.
- Review may question embedded WebKit login and usage-page scraping of third-party services.
- Review notes will need a clear explanation of what the app does, what data stays local, and how reviewers can test without private user accounts.
- Banking, tax, agreements, app metadata, screenshots, privacy labels, and final submission remain Account Holder / App Store Connect approval gates.

Mac App Store prep tasks:

- Use `scripts/build-mas-app.sh` as the separate MAS build configuration.
- Keep Sparkle and update-related settings disabled in the MAS build.
- Sign the app with an Apple Distribution certificate and package it with a Mac App Store installer distribution certificate before upload.
- Add App Sandbox entitlements:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.network.client`
  - storage access limited to app container defaults where possible.
- Verify whether `SMAppService` launch-at-login works as expected under sandbox and App Review expectations.
- Prepare App Store metadata, privacy labels, screenshots, support URL, marketing URL, and review notes.
- Prepare the upload machine with Xcode, altool, or Transporter and approved App Store Connect upload authentication.
- Create a reviewer demo plan that does not require sharing private Claude or ChatGPT credentials.
- Use `docs/app-store-submission-packet.md` for the draft metadata, privacy label notes, reviewer notes, screenshot requirements, and reviewer test plan.

## Apple Access Checklist

Do not share a personal Apple ID password in chat.

Detailed invitation and revocation guidance lives in `docs/apple-access-handoff.md`.

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
Publication/legal gates live in `docs/publication-legal-checklist.md`.

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
- Public install, update, Gatekeeper, and Launch at Login reports should use `.github/ISSUE_TEMPLATE/install-update-bug.yml`.
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

- Current public GitHub/Sparkle release: `v1.0.20` / build `21`.
- Public release verification: `./scripts/verify-public-release.sh v1.0.20 1.0.20 21` passes for GitHub Release assets, GitHub Pages, `appcast.xml`, and the Sparkle update ZIP.
- Direct Developer ID distribution docs: `docs/apple-distribution-readiness.md`.
- Prompt-to-artifact completion audit: `docs/apple-distribution-completion-audit.md`.
- Apple credential setup: `docs/apple-credential-runbook.md`.
- Local signing/notarization verifier: `scripts/check-apple-distribution.sh`; it reports Developer ID, Apple Distribution, and Mac App Store installer distribution identities separately.
- GitHub release secret verifier: `scripts/check-github-release-secrets.sh`.
- Local release preflight: `scripts/preflight-release.sh`.
- Public release verifier: `scripts/verify-public-release.sh`.
- GitHub signed release workflow: `.github/workflows/release.yml`.
- Consolidated Apple distribution audit: `scripts/audit-apple-distribution.sh`.
- Current GitHub release: `https://github.com/MediaPublishing/token-monitor/releases/tag/v1.0.20`.
- GitHub CI workflow: `.github/workflows/ci.yml` runs release script smoke checks, tests, direct app build, MAS build, MAS build verification, and MAS readiness checks.
- GitHub workflows use Node-24-compatible action pins where available and set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`.
- Mac App Store feasibility audit: `docs/mac-app-store-feasibility.md`.
- App Store submission packet: `docs/app-store-submission-packet.md`.
- App Store Connect identity checklist: `docs/app-store-connect-identity.md`.
- MAS candidate build path: `scripts/build-mas-app.sh`.
- MAS build verifier: `scripts/verify-mas-build.sh`.
- MAS upload package builder: `scripts/package-mas-pkg.sh`.
- MAS upload handoff checker: `scripts/check-app-store-upload-readiness.sh`.
- MAS submission preflight: `scripts/preflight-mas-submission.sh`.
- MAS human/App Store Connect gate checker: `scripts/check-app-store-submission-gates.sh`.
- MAS sandbox smoke test checklist: `docs/mas-sandbox-smoke-test.md`.
- MAS readiness checker: `scripts/check-mas-readiness.sh`.
- Release recovery runbook: `docs/release-recovery-runbook.md`.
- Release recovery checker: `scripts/check-release-recovery-readiness.sh`.
- Draft MAS entitlements: `packaging/TokenMonitorMAS.entitlements`.
- Marketing and App Store draft metadata: `docs/marketing-launch-kit.md`.
- Publication/legal checklist: `docs/publication-legal-checklist.md`.
- Public privacy summary: `docs/privacy.md`.
- Public parser issue form with privacy warnings: `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`.
- Public install/update issue form with Apple credential and debug dump warnings: `.github/ISSUE_TEMPLATE/install-update-bug.yml`.
- Regression coverage: `swift test` passes with 34 tests.
- Earlier release workflow: `https://github.com/MediaPublishing/token-monitor/actions/runs/25496438297` passed for `v1.0.20`.
- Current CI evidence: run `gh run list --repo MediaPublishing/token-monitor --branch main --limit 1` and confirm the latest `main` run passed release script smoke checks, tests, direct app build, MAS build, MAS verification, and MAS readiness.

Current blockers:

- No Developer ID Application certificate is installed locally.
- No Apple Distribution certificate is installed locally.
- No Mac App Store installer distribution certificate is installed locally.
- No local `TOKEN_MONITOR_NOTARY_PROFILE` is configured.
- The current `dist/TokenMonitor.app` is version `1.0.20` build `21` and ad hoc signed.
- Gatekeeper rejects the current local app and DMG.
- The current DMG has no stapled notarization ticket.
- GitHub has `SPARKLE_PRIVATE_KEY` configured, but Developer ID signing/notarization secrets are not configured with real Apple credentials.
- Mac App Store submission remains a separate, not-ready track until Apple Distribution signing, App Store Connect setup, sandbox smoke testing, reviewer accounts, screenshots, and final approvals are complete.
- The MAS candidate build removes Sparkle and passes local verification, but it has not been signed with an Apple Distribution certificate or smoke-tested with real reviewer accounts under App Sandbox.
- The MAS upload package path exists, but it has not been signed with a Mac App Store installer distribution identity.
- The MAS upload handoff is not ready because no submitted package, App Store Connect upload tool, or upload authentication has been configured on this machine.
- App Store Connect identity approval is not complete until the Account Holder or approved operator confirms Team ID, Bundle ID, SKU, and category.
- Repository license and final legal/privacy approvals remain human approval gates before broad promotion or App Store submission.

Conclusion:

- The repository is prepared for Apple Developer access.
- The objective is not complete until a signed, notarized, stapled Developer ID release is produced and verified with real Apple credentials.

## Source References

- Apple Developer ID: https://developer.apple.com/developer-id/
- Apple notarization docs: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Store Connect API: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
- App Store Connect build uploads: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- App Store Connect role permissions: https://developer.apple.com/help/app-store-connect/reference/role-permissions
