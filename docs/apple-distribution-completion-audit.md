# Apple Distribution Completion Audit

Last reviewed: 2026-05-06

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
| Produce signed Developer ID app | `TOKEN_MONITOR_CODESIGN_IDENTITY=... ./scripts/package-release.sh` | Script path exists, but no `Developer ID Application` identity is installed locally. | Blocked |
| Notarize and staple DMG | `TOKEN_MONITOR_NOTARIZE=1 TOKEN_MONITOR_NOTARY_PROFILE=... ./scripts/package-release.sh` | Script path exists, but no local `TOKEN_MONITOR_NOTARY_PROFILE` is configured. | Blocked |
| Verify Gatekeeper acceptance | `spctl --assess --type execute --verbose=4 dist/TokenMonitor.app` and `xcrun stapler validate dist/TokenMonitor-macOS.dmg` | Current ad hoc app and DMG are rejected and the DMG has no stapled ticket, as expected before credentials. | Blocked |
| Check GitHub release secrets | `./scripts/check-github-release-secrets.sh` | `SPARKLE_PRIVATE_KEY` exists; Developer ID and notary secrets are missing. | Partially prepared |
| Keep release operations repeatable | `.github/workflows/release.yml`, `scripts/package-release.sh`, `scripts/preflight-release.sh`, `scripts/verify-public-release.sh` | `v1.0.19` release workflow passed; public release verifier passed for `v1.0.19 1.0.19 20`. | Prepared |
| Assess Mac App Store feasibility | `docs/mac-app-store-feasibility.md` | Documents MAS as a separate track with Sparkle removed and App Review risks called out. | Prepared |
| Build a MAS candidate | `./scripts/build-mas-app.sh` | Local MAS candidate builds as `1.0.19` build `20`. | Prepared |
| Verify MAS candidate shape | `./scripts/verify-mas-build.sh` | Verifies no Sparkle files, no Sparkle binary link, no `SU*` update keys, sandbox/network entitlements, and valid local signature. | Prepared |
| Check MAS static readiness | `./scripts/check-mas-readiness.sh` | Reports zero static blockers and warns that WebKit sessions and Login Items need smoke testing. | Prepared with warnings |
| Sign MAS build for App Store | `TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: ..." ./scripts/build-mas-app.sh` | No Apple Distribution certificate is installed locally. | Blocked |
| Smoke-test sandboxed MAS behavior | Manual MAS binary test for login, refresh, snapshots, diagnostics, and Launch at Login | Not possible without reviewer/test accounts and App Store Connect context. | Blocked |
| Prepare App Store submission material | `docs/app-store-submission-packet.md` | Draft metadata, privacy labels, reviewer notes, screenshots, and test plan are documented. | Prepared |
| Prepare marketing setup | `docs/marketing-launch-kit.md`, `landing/index.html`, `README.md` | Direct distribution copy, App Store draft metadata, screenshot inventory, launch checklist, and approval gates exist. | Prepared |
| Preserve legal/privacy gates | `docs/publication-legal-checklist.md`, `docs/privacy.md` | License, privacy policy, privacy labels, and public claims remain human approval gates. | Prepared with human gates |
| Route support safely | `SUPPORT.md`, `SECURITY.md` | Public support and private vulnerability routes exist and warn against posting secrets/debug dumps. | Prepared |
| Keep issue fixing safe | `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`, `docs/apple-distribution-readiness.md` | Parser issue template warns that GitHub Issues are public and blocks raw debug dump sharing. | Prepared |
| Maintain regression coverage | `swift test` | Local and CI tests pass with 33 tests. | Prepared |
| Verify latest CI | GitHub Actions CI | Run `25464057692` passed tests, direct build, MAS build, MAS verification, and MAS readiness. | Prepared |

## Current Verified Commands

Last verified on 2026-05-06:

```bash
swift test
./scripts/check-apple-distribution.sh
./scripts/check-github-release-secrets.sh
./scripts/build-mas-app.sh
./scripts/verify-mas-build.sh
./scripts/check-mas-readiness.sh
./scripts/verify-public-release.sh v1.0.19 1.0.19 20
```

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
- App Store Connect app record.
- Agreements, tax, and banking completed by the Account Holder.
- Final privacy policy and App Privacy labels approved by a human/legal reviewer.
- Reviewer test accounts or approved review plan.
- Screenshots captured from the submitted MAS binary.
- Sandbox smoke test for WebKit login, refresh, snapshots, diagnostics, and Launch at Login.
- Final Account Holder approval to submit.

## Post-Credential Operator Sequence

After Apple credentials are available:

```bash
TOKEN_MONITOR_REQUIRE_SIGNING_SECRETS=1 ./scripts/check-github-release-secrets.sh

xcrun notarytool store-credentials token-monitor-notary

./scripts/preflight-release.sh --require-signing-secrets

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh

codesign --verify --deep --strict dist/TokenMonitor.app
spctl --assess --type execute --verbose=4 dist/TokenMonitor.app
xcrun stapler validate dist/TokenMonitor-macOS.dmg
```

For a published release:

```bash
TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 \
./scripts/verify-public-release.sh <tag> <version> <build>
```

## Completion Criteria

Do not mark the Apple distribution objective complete until all of these are true:

1. A Developer ID signed app verifies with `codesign --verify --deep --strict`.
2. Gatekeeper accepts the app with `spctl --assess --type execute --verbose=4`.
3. The DMG has a stapled notarization ticket.
4. GitHub release assets and the Sparkle appcast are live and verified.
5. If Mac App Store submission is pursued, the MAS binary is Apple Distribution signed, sandbox smoke-tested, and explicitly approved by the Account Holder.
6. Legal/privacy/license and public marketing claims have received required human approval.

