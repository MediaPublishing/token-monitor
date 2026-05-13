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
| Verify Gatekeeper acceptance | `./scripts/check-apple-distribution.sh --require-ready` | Current ad hoc app and DMG are rejected and the DMG has no stapled ticket, as expected before credentials. Strict mode fails until credentials exist. | Blocked |
| Check GitHub release secrets | `./scripts/check-github-release-secrets.sh` | Verified 2026-05-12: `SPARKLE_PRIVATE_KEY` exists; six Developer ID and notary secrets are missing. | Partially prepared |
| Keep release operations repeatable | `.github/workflows/release.yml`, `scripts/package-release.sh`, `scripts/preflight-release.sh`, `scripts/verify-public-release.sh` | Current CI passed for commit `0cbca35`; release workflow uses the package-level strict distribution gate and blocks signed non-notarized releases. | Prepared |
| Verify Sparkle update path | `./scripts/package-release.sh --require-distribution-ready`, `TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 ./scripts/verify-public-release.sh <tag> <version> <build>` | Strict local release verifies the versioned update ZIP; public signed-release verification downloads and checks the published update ZIP. | Prepared |
| Keep the repository publicly reachable | GitHub repository settings | Verified 2026-05-12: `MediaPublishing/token-monitor` is public and uses `main` as the default branch. | Prepared |
| Assess Mac App Store feasibility | `docs/mac-app-store-feasibility.md` | Documents MAS as a separate track with Sparkle removed and App Review risks called out. | Prepared |
| Build a MAS candidate | `./scripts/build-mas-app.sh` | Local MAS candidate builds as `1.0.20` build `21`. | Prepared |
| Verify MAS candidate shape | `./scripts/verify-mas-build.sh` | Verifies no Sparkle files, no Sparkle binary link, no `SU*` update keys, sandbox/network entitlements, and valid local signature. | Prepared |
| Check MAS static readiness | `./scripts/check-mas-readiness.sh` | Reports zero static blockers and warns that WebKit sessions and Login Items need smoke testing. | Prepared with warnings |
| Sign MAS build for App Store | `TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: ..." ./scripts/build-mas-app.sh` | No Apple Distribution certificate is installed locally. | Blocked |
| Smoke-test sandboxed MAS behavior | Manual MAS binary test for login, refresh, snapshots, diagnostics, and Launch at Login | Not possible without reviewer/test accounts and App Store Connect context. | Blocked |
| Prepare App Store submission material | `docs/app-store-submission-packet.md` | Draft metadata, privacy labels, reviewer notes, screenshots, and test plan are documented. | Prepared |
| Prepare marketing setup | `docs/marketing-launch-kit.md`, `landing/index.html`, `README.md` | Direct distribution copy, App Store draft metadata, screenshot inventory, launch checklist, and approval gates exist. | Prepared |
| Preserve legal/privacy gates | `docs/publication-legal-checklist.md`, `docs/privacy.md` | License, privacy policy, privacy labels, and public claims remain human approval gates. | Prepared with human gates |
| Route support safely | `SUPPORT.md`, `SECURITY.md` | Public support and private vulnerability routes exist and warn against posting secrets/debug dumps. | Prepared |
| Keep issue fixing safe | `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`, `docs/apple-distribution-readiness.md` | Parser issue template warns that GitHub Issues are public and blocks raw debug dump sharing. | Prepared |
| Maintain regression coverage | `swift test` | Local and CI tests pass with 34 tests. | Prepared |
| Verify latest CI | GitHub Actions CI | Run `25496427624` passed tests, direct build, MAS build, MAS verification, and MAS readiness. | Prepared |

## Current Verified Commands

Last verified on 2026-05-13:

```bash
./scripts/check-apple-distribution.sh
./scripts/check-github-release-secrets.sh
./scripts/check-github-release-secrets.sh --require-signing-secrets
./scripts/check-apple-distribution.sh --require-ready
./scripts/verify-public-release.sh v1.0.20 1.0.20 21
gh pr list --repo MediaPublishing/token-monitor --state open --json number,title,updatedAt,url
gh issue list --repo MediaPublishing/token-monitor --state open --json number,title,labels,updatedAt,url
gh release view v1.0.20 --repo MediaPublishing/token-monitor --json tagName,name,isDraft,isPrerelease,publishedAt,url,assets
gh repo view MediaPublishing/token-monitor --json visibility,url,defaultBranchRef
```

Recent previously verified commands:

- `swift test` passed with 34 tests for the current `1.0.20` release line.
- Shell syntax checks passed for the release scripts after the strict release gate updates.
- `./scripts/build-mas-app.sh` passed for the MAS candidate.
- `./scripts/verify-mas-build.sh` passed for the MAS candidate.
- `./scripts/check-mas-readiness.sh` reported zero static blockers, with manual smoke-test warnings.
- `./scripts/verify-public-release.sh v1.0.20 1.0.20 21` passed for GitHub Release assets, GitHub Pages, `appcast.xml`, and the Sparkle update ZIP.
- `./scripts/check-github-release-secrets.sh --require-signing-secrets` fails as expected until Developer ID and notary secrets exist.
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

This verifies the published DMG and the published Sparkle update ZIP.

For a GitHub Actions rebuild after Developer ID credentials are configured, run the `Release` workflow manually with the existing tag and enable `require_developer_id`.

## Completion Criteria

Do not mark the Apple distribution objective complete until all of these are true:

1. A Developer ID signed app verifies with `codesign --verify --deep --strict`.
2. Gatekeeper accepts the app with `spctl --assess --type execute --verbose=4`.
3. The DMG has a stapled notarization ticket.
4. The strict package step verifies the Sparkle update ZIP contains a signed `TokenMonitor.app` with the expected version/build.
5. GitHub release assets, the Sparkle appcast, and the public Sparkle update ZIP are live and verified.
6. If Mac App Store submission is pursued, the MAS binary is Apple Distribution signed, sandbox smoke-tested, and explicitly approved by the Account Holder.
7. Legal/privacy/license and public marketing claims have received required human approval.
