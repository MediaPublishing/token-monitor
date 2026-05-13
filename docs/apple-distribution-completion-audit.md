# Apple Distribution Completion Audit

Last reviewed: 2026-05-13

## Objective

Assess and prepare Token Monitor for Apple distribution, including App Store feasibility, signing/notarization, release operations, marketing setup, and ongoing issue fixing once appropriate Apple Developer access is available.

This audit is the prompt-to-artifact checklist for deciding whether the Apple distribution objective is complete.

## Status

Not complete.

The repository is prepared for Apple Developer access, but the distribution objective cannot be completed until real Apple credentials are available and a signed, notarized, stapled Developer ID release is produced and verified.

## Prompt-To-Artifact Checklist

| Requirement | Artifact or command | Current evidence | Status |
| --- | --- | --- | --- |
| Assess direct Apple distribution | `docs/apple-distribution-readiness.md` | Documents Developer ID DMG as the primary path and lists acceptance checks. | Prepared |
| Produce signed Developer ID app | `TOKEN_MONITOR_CODESIGN_IDENTITY=... ./scripts/package-release.sh --require-distribution-ready` | Script path exists, but no `Developer ID Application` identity is installed locally. | Blocked |
| Notarize and staple DMG | `TOKEN_MONITOR_NOTARIZE=1 TOKEN_MONITOR_NOTARY_PROFILE=... ./scripts/package-release.sh --require-distribution-ready` | Script path exists, but no local `TOKEN_MONITOR_NOTARY_PROFILE` is configured. | Blocked |
| Verify local Apple signing identities | `./scripts/check-apple-distribution.sh` | Reports Developer ID Application, Apple Distribution, and Mac App Store installer distribution identities separately. Current machine has none installed. | Blocked |
| Verify Gatekeeper acceptance | `./scripts/check-apple-distribution.sh --require-ready` | Current ad hoc app and DMG are rejected and the DMG has no stapled ticket, as expected before credentials. Strict mode fails until credentials exist. | Blocked |
| Document Apple access handoff | `docs/apple-access-handoff.md` | Documents minimum practical roles, invitation checklist, safe-to-share values, blocked secrets, and revocation steps. | Prepared |
| Run consolidated completion audit | `./scripts/audit-apple-distribution.sh --require-complete` | Script path exists and runs the repo, CI, App Store metadata, screenshot, App Store Connect identity, secret, Developer ID, MAS upload, App Store human gate, and publication/legal gate checks in one safe non-uploading audit. Strict mode fails until Apple credentials and approvals exist. | Prepared |
| Check GitHub release secrets | `./scripts/check-github-release-secrets.sh` | Verified 2026-05-13: `SPARKLE_PRIVATE_KEY` exists; six Developer ID and notary secrets are missing. GitHub secret values cannot be read locally, so the Release workflow validates the Developer ID identity class at runtime. | Partially prepared |
| Keep release operations repeatable | `.github/workflows/release.yml`, `scripts/package-release.sh`, `scripts/preflight-release.sh`, `scripts/verify-public-release.sh` | CI covers release script smoke checks; the release workflow uses the package-level strict distribution gate and blocks signed non-notarized releases. | Prepared |
| Gate release version consistency | `./scripts/check-release-version-consistency.sh`, `.github/workflows/release.yml` | Checks that `CFBundleShortVersionString` is semantic-version-like, `CFBundleVersion` is a positive integer, and release tags match `v<version>` before the Release workflow packages assets. | Prepared |
| Smoke-check release scripts in CI | `.github/workflows/ci.yml` | CI now runs shell syntax checks, release/distribution script `--help` checks, and the expected `package-mas-pkg.sh` no-identity failure path. | Prepared |
| Verify public and Sparkle ZIP paths | `./scripts/package-release.sh --require-distribution-ready`, `TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 ./scripts/verify-public-release.sh <tag> <version> <build>` | Strict local release verifies both the GitHub release ZIP and the versioned Sparkle update ZIP; public signed-release verification downloads and checks both published ZIPs. | Prepared |
| Prepare release recovery path | `docs/release-recovery-runbook.md`, `./scripts/check-release-recovery-readiness.sh --require-ready` | Documents first response, hotfix release, appcast rollback, Mac App Store recovery, credential exposure handling, support triage, and prohibited recovery actions. Checker verifies that the workflow, verifier, and runbook cover the recovery path. | Prepared |
| Keep the repository publicly reachable | GitHub repository settings | Verified 2026-05-12: `MediaPublishing/token-monitor` is public and uses `main` as the default branch. | Prepared |
| Check public repository hygiene | `./scripts/check-public-repo-hygiene.sh`, `.github/workflows/release.yml` | Scans tracked files for high-risk secret file paths and obvious secret token patterns before public distribution. CI, release preflight, the consolidated audit, and the Release workflow run this before public assets are packaged or uploaded. This is a local hygiene gate, not a replacement for human legal/privacy review. | Prepared |
| Check GitHub security reporting | `./scripts/check-github-security-reporting.sh --require-private-vulnerability-reporting` | Verifies the repo is public, GitHub Issues are enabled, and private vulnerability reporting is enabled for sensitive reports. | Prepared |
| Check public distribution URLs | `./scripts/check-public-distribution-urls.sh` | Verifies that Support, Marketing, Privacy, latest release, latest DMG, and security-reporting URLs are HTTPS and reachable. | Prepared |
| Assess Mac App Store feasibility | `docs/mac-app-store-feasibility.md` | Documents MAS as a separate track with Sparkle removed and App Review risks called out. | Prepared |
| Build a MAS candidate | `./scripts/build-mas-app.sh` | Local MAS candidate builds as `1.0.20` build `21`. | Prepared |
| Verify MAS candidate shape | `./scripts/verify-mas-build.sh` | Verifies no Sparkle files, no Sparkle binary link, no `SU*` update keys, sandbox/network entitlements, and valid local signature. Strict `--require-apple-distribution` mode is available for the submitted binary. | Prepared |
| Keep MAS update UI App Store-safe | `Sources/TokenMonitorApp/SettingsView.swift`, `Sources/TokenMonitorApp/AppUpdateController.swift`, `swift test` | MAS builds show Mac App Store update copy and use a no-op update controller instead of Sparkle UI. Direct DMG builds keep Sparkle update controls. | Prepared |
| Check MAS static readiness | `./scripts/check-mas-readiness.sh` | Reports zero static blockers, verifies the App Store category marker, and warns that WebKit sessions and Login Items need smoke testing. | Prepared with warnings |
| Check App Store Connect identity | `docs/app-store-connect-identity.md`, `./scripts/check-app-store-identity.sh --require-ready` | Documents the current app name, bundle ID, category, minimum macOS version, version/build, and explicit approvals for Apple Team ID, Bundle ID, SKU, and category. Strict mode fails until human identity approvals exist. | Prepared with human gates |
| Run MAS submission technical preflight | `TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: ..." ./scripts/preflight-mas-submission.sh` | Script path exists and requires App Store Connect identity approval plus Apple Distribution signing before verifying the submitted MAS binary. | Blocked until credentials |
| Sign MAS build for App Store | `TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: ..." ./scripts/build-mas-app.sh` | No Apple Distribution certificate is installed locally. | Blocked |
| Package MAS upload pkg | `TOKEN_MONITOR_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: ..." ./scripts/package-mas-pkg.sh` | Script path exists, verifies the app with `--require-apple-distribution`, and produces `dist/mas/TokenMonitor-macOS-AppStore.pkg`; no installer distribution certificate is installed locally. | Blocked |
| Check MAS upload handoff | `./scripts/check-app-store-upload-readiness.sh --require-ready` | Script path exists and checks the signed MAS pkg, confirms the package uses a Mac App Store installer distribution identity, checks local upload tool availability, and checks approved upload authentication inputs without uploading anything. Current machine has no MAS pkg or upload credentials. | Blocked |
| Smoke-test sandboxed MAS behavior | `docs/mas-sandbox-smoke-test.md`, `docs/mas-sandbox-smoke-test-receipt.md` | Checklist and receipt template exist for login, refresh, snapshots, diagnostics, Launch at Login, evidence capture, privacy review, and fail conditions. Execution is not possible without reviewer/test accounts and App Store Connect context. | Blocked |
| Prepare App Store submission material | `docs/app-store-submission-packet.md` | Draft metadata, privacy labels, reviewer notes, screenshots, and test plan are documented. | Prepared |
| Validate App Store metadata limits | `./scripts/check-app-store-metadata.sh` | Script path exists and checks app name, subtitle, promotional text, description, keyword byte limit, keyword minimum length, and HTTPS URLs against the draft submission packet. | Prepared |
| Prepare App Store privacy labels | `docs/app-store-privacy-labels.md` | Documents draft App Store Connect answers, no-collection rationale, tracking answer, privacy URL, change triggers, and the privacy approval gate. Final approval remains a human/legal gate. | Prepared with human gate |
| Prepare App Store screenshots | `docs/app-store-screenshot-checklist.md`, `./scripts/check-app-store-screenshots.sh --require-ready` | Documents Mac screenshot counts, formats, dimensions, sanitized capture set, filename convention, and screenshot approval gate. Script validates screenshot count, file type, and accepted Mac dimensions. Actual screenshots remain blocked until the submitted MAS binary exists. | Prepared with human gate |
| Gate App Store human approvals | `./scripts/check-app-store-submission-gates.sh --require-human-gates` | Script exists and fails strict mode until Account Holder approval, App Store Connect readiness, privacy approval, reviewer plan, screenshots, final URLs, and sandbox smoke test are explicitly acknowledged. | Prepared with human gates |
| Prepare marketing setup | `docs/marketing-launch-kit.md`, `landing/index.html`, `README.md` | Direct distribution copy, App Store draft metadata, screenshot inventory, launch checklist, and approval gates exist. | Prepared |
| Preserve legal/privacy gates | `docs/publication-legal-checklist.md`, `docs/privacy.md`, `./scripts/check-publication-legal-gates.sh --require-legal-gates` | License, privacy policy, privacy labels, support/security routes, and public claims remain human approval gates. Strict checker blocks broad promotion or App Store completion until explicit acknowledgements exist. | Prepared with human gates |
| Route support safely | `SUPPORT.md`, `SECURITY.md` | Public support and private vulnerability routes exist and warn against posting secrets/debug dumps. | Prepared |
| Keep issue fixing safe | `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`, `.github/ISSUE_TEMPLATE/install-update-bug.yml`, `docs/apple-distribution-readiness.md` | Parser and install/update issue templates warn that GitHub Issues are public and block raw debug dumps, private account data, Apple credentials, certificates, private keys, and GitHub Secrets. | Prepared |
| Maintain regression coverage | `swift test` | Local and CI tests pass with 34 tests. | Prepared |
| Verify current CI | `gh run list --repo MediaPublishing/token-monitor --branch main --limit 1` | Current-state CI must pass release script smoke checks, tests, direct build, MAS build, MAS verification, and MAS readiness. | Prepared when current run is green |

## Current Verified Commands

Last verified on 2026-05-13:

```bash
./scripts/check-apple-distribution.sh
./scripts/check-github-release-secrets.sh
./scripts/check-app-store-submission-gates.sh
./scripts/check-app-store-submission-gates.sh --require-human-gates
./scripts/check-app-store-metadata.sh
./scripts/check-app-store-identity.sh
./scripts/check-app-store-identity.sh --require-ready
./scripts/check-release-recovery-readiness.sh
./scripts/check-release-recovery-readiness.sh --require-ready
./scripts/check-release-version-consistency.sh
./scripts/check-release-version-consistency.sh --tag v1.0.20 --require-tag
./scripts/check-public-repo-hygiene.sh
./scripts/check-github-security-reporting.sh --require-private-vulnerability-reporting
./scripts/check-public-distribution-urls.sh
./scripts/audit-apple-distribution.sh --help
./scripts/package-mas-pkg.sh --help
./scripts/check-app-store-upload-readiness.sh --help
./scripts/verify-public-release.sh --help
./scripts/check-github-release-secrets.sh --require-signing-secrets
./scripts/check-apple-distribution.sh --require-ready
./scripts/verify-public-release.sh v1.0.20 1.0.20 21
gh pr list --repo MediaPublishing/token-monitor --state open --json number,title,updatedAt,url
gh issue list --repo MediaPublishing/token-monitor --state open --json number,title,labels,updatedAt,url
gh release view v1.0.20 --repo MediaPublishing/token-monitor --json tagName,name,isDraft,isPrerelease,publishedAt,url,assets
gh repo view MediaPublishing/token-monitor --json visibility,url,defaultBranchRef
gh run list --repo MediaPublishing/token-monitor --branch main --limit 1
```

Recent previously verified commands:

- `swift test` passed with 34 tests for the current `1.0.20` release line.
- Shell syntax checks and release/distribution script help checks pass locally and are covered by CI.
- `./scripts/audit-apple-distribution.sh --require-complete` is available as the final non-uploading completion audit, includes App Store metadata validation, and is expected to fail until real credentials and approvals exist.
- `./scripts/check-github-security-reporting.sh --require-private-vulnerability-reporting` passes after private vulnerability reporting was enabled on GitHub.
- `./scripts/check-public-distribution-urls.sh` verifies public Support, Marketing, Privacy, Release, DMG, and security-reporting URLs.
- `./scripts/build-mas-app.sh` passed for the MAS candidate.
- `./scripts/verify-mas-build.sh` passed for the MAS candidate.
- `./scripts/check-mas-readiness.sh` reported zero static blockers, with manual smoke-test warnings.
- `./scripts/verify-public-release.sh v1.0.20 1.0.20 21` passed for GitHub Release assets, GitHub Pages, `appcast.xml`, and the Sparkle update ZIP.
- `./scripts/check-github-release-secrets.sh --require-signing-secrets` fails as expected until Developer ID and notary secrets exist.
- `./scripts/check-app-store-submission-gates.sh --require-human-gates` fails as expected until all human/App Store Connect acknowledgements are set.
- `./scripts/package-mas-pkg.sh` fails as expected until Apple Distribution and installer distribution identities are available.
- `./scripts/check-app-store-upload-readiness.sh` reports missing MAS upload package, upload tool, and upload authentication until the final upload machine is prepared.
- `./scripts/check-apple-distribution.sh` reports missing Mac App Store installer distribution identity as App Store upload-package readiness context.
- `./scripts/check-apple-distribution.sh --require-ready` fails as expected until a signed/notarized/stapled release exists.

## Missing Inputs

Required before Developer ID distribution can be completed:

- Active Apple Developer Program membership.
- `Developer ID Application` certificate installed locally or exported as a protected `.p12` for CI.
- Local `notarytool` profile, for example `token-monitor-notary`.
- GitHub repository secrets:
  - `TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64`
  - `TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_PASSWORD`
  - `TOKEN_MONITOR_CODESIGN_IDENTITY`
  - `TOKEN_MONITOR_NOTARY_APPLE_ID`
  - `TOKEN_MONITOR_NOTARY_TEAM_ID`
  - `TOKEN_MONITOR_NOTARY_APP_PASSWORD`
  - optional `TOKEN_MONITOR_RELEASE_KEYCHAIN_PASSWORD`

Required before Mac App Store submission can be completed:

- Apple Distribution certificate.
- Mac App Store installer distribution certificate.
- App Store Connect app record.
- Approved Apple Team ID, Bundle ID, SKU, and App Store category.
- App Store Connect upload tool and approved upload authentication method on the upload machine.
- Agreements, tax, and banking completed by the Account Holder.
- Final privacy policy and App Privacy labels approved by a human/legal reviewer.
- App Store privacy answers reviewed against `docs/app-store-privacy-labels.md`.
- Reviewer test accounts or approved review plan.
- Screenshots captured from the submitted MAS binary.
- Screenshot dimensions and privacy reviewed against `docs/app-store-screenshot-checklist.md`.
- Sandbox smoke test for WebKit login, refresh, snapshots, diagnostics, and Launch at Login.
- Final Account Holder approval to submit.

## Post-Credential Operator Sequence

After Apple credentials are available:

```bash
./scripts/check-github-release-secrets.sh --require-signing-secrets

xcrun notarytool store-credentials token-monitor-notary

./scripts/preflight-release.sh --require-signing-secrets

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh --require-distribution-ready

codesign --verify --deep --strict dist/TokenMonitor.app
spctl --assess --type execute --verbose=4 dist/TokenMonitor.app
xcrun stapler validate dist/TokenMonitor-macOS.dmg
```

For a published release:

```bash
TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 \
./scripts/verify-public-release.sh <tag> <version> <build>
```

This verifies the published DMG, published GitHub release ZIP, and published Sparkle update ZIP.

For a GitHub Actions rebuild after Developer ID credentials are configured, run the `Release` workflow manually with the existing tag and enable `require_developer_id`.

For Mac App Store upload readiness after the technical MAS preflight and sandbox smoke test:

```bash
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
TOKEN_MONITOR_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)" \
./scripts/preflight-mas-submission.sh

./scripts/check-app-store-identity.sh --require-ready

./scripts/check-app-store-upload-readiness.sh --require-ready

TOKEN_MONITOR_APP_STORE_ACCOUNT_HOLDER_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_CONNECT_READY=1 \
TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_SCREENSHOTS_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_SUPPORT_URL_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_SANDBOX_SMOKE_TEST_PASSED=1 \
./scripts/check-app-store-submission-gates.sh --require-human-gates

./scripts/audit-apple-distribution.sh --require-complete --run-tests
```

## Completion Criteria

Do not mark the Apple distribution objective complete until all of these are true:

1. A Developer ID signed app verifies with `codesign --verify --deep --strict`.
2. Gatekeeper accepts the app with `spctl --assess --type execute --verbose=4`.
3. The DMG has a stapled notarization ticket.
4. The strict package step verifies both ZIP artifacts contain a signed `TokenMonitor.app` with the expected version/build.
5. GitHub release assets, the Sparkle appcast, the public GitHub release ZIP, and the public Sparkle update ZIP are live and verified.
6. If Mac App Store submission is pursued, the MAS binary is Apple Distribution signed, `dist/mas/TokenMonitor-macOS-AppStore.pkg` is signed with a Mac App Store installer distribution identity, the upload handoff passes `./scripts/check-app-store-upload-readiness.sh --require-ready`, the binary is sandbox smoke-tested, and `./scripts/check-app-store-submission-gates.sh --require-human-gates` passes with explicit human/App Store Connect acknowledgements.
7. Legal/privacy/license and public marketing claims have received required human approval.
