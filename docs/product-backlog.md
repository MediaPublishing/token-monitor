# Token Monitor Product Backlog

Last reviewed: 2026-05-13

## Current Release State

- Current public preview release: `v1.0.25` / build `26`.
- Public download: `https://github.com/MediaPublishing/token-monitor/releases/tag/v1.0.25`.
- GitHub Pages landing page: `https://mediapublishing.github.io/token-monitor/`.
- Sparkle appcast: `https://mediapublishing.github.io/token-monitor/appcast.xml`.
- Public builds remain preview builds until Developer ID signing and notarization are resumed.

## Current Product Policy

- Direct GitHub DMG remains the active distribution channel.
- Apple Developer ID signing, notarization, and Mac App Store work are paused until explicitly resumed.
- Automatic update checks are off by default from `v1.0.22`.
- Manual update checks remain available through Settings.
- Debug reports must remain opt-in and draft-only. Do not send or post private usage dumps automatically.
- Public GitHub Issues must not include raw debug dumps, account data, chat titles, cookies, tokens, Apple credentials, or GitHub secrets.

## Active Priorities

| Priority | Area | Status | Next action |
| --- | --- | --- | --- |
| P0 | Parser reliability | Active | Treat Claude and ChatGPT layout changes as hotfix candidates when users report parse failures. |
| P0 | Install/update trust | Active | Keep Gatekeeper and update behavior clearly documented while builds are unsigned previews. |
| P1 | Menu bar clarity | Active | Continue refining status bar display only when screenshots show real confusion or space pressure. |
| P1 | Release operations | Active | Keep release assets, appcast, GitHub Pages, README, and landing page aligned on every preview release. |
| P2 | Marketing setup | Active | Keep landing page screenshots and install guidance current; avoid App Store or notarization claims until true. |
| Paused | Apple distribution | Paused | Resume only after explicit approval and required Apple credentials/access exist. |

## Release Checklist For Preview Updates

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` when the app binary changes.
2. Update README and landing page links to the new preview tag.
3. Run local verification:
   - `swift test`
   - `./scripts/build-app.sh`
   - `./scripts/check-release-version-consistency.sh --tag <tag> --require-tag`
   - `./scripts/check-public-repo-hygiene.sh`
4. Commit and push to `main`.
5. Create or update the GitHub prerelease.
6. Confirm CI and Release workflows pass.
7. Run public verification:
   - `./scripts/verify-public-release.sh <tag> <version> <build>`
   - `./scripts/check-public-distribution-urls.sh`
   - `./scripts/check-github-release-channel.sh`
8. Confirm GitHub Pages and `appcast.xml` show the intended version and release notes.

## Issue Triage Rules

- Parser/layout reports: request sanitized text, app version/build, provider, macOS version, and a redacted screenshot only if needed.
- Install/update reports: check release channel, appcast version, DMG reachability, Gatekeeper status, and whether the user is on a preview build.
- Privacy-sensitive reports: route to private vulnerability reporting or user-reviewed email drafts. Do not ask users to post raw debug dumps publicly.
- If a fix affects user-facing behavior, add or update a focused regression test before release.

## Deferred Decisions

- Whether to resume Developer ID signing and notarization.
- Whether to pursue the Mac App Store track separately.
- Whether to add a formal public license or keep the public repository source-visible without a license.
- Whether to promote beyond the current preview audience.
