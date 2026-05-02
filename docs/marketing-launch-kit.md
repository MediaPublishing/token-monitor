# Token Monitor Marketing Launch Kit

Last reviewed: 2026-05-02

## Purpose

This file keeps public-facing launch assets in one place so GitHub Releases, the landing page, direct DMG distribution, and a possible future Mac App Store submission stay consistent.

Do not publish compatibility, privacy, security, or App Store approval claims from this file without a final human review.

## Positioning

Primary audience:

- Claude, ChatGPT, and Codex power users who need a quick quota view without opening multiple account pages.
- Solo operators and small teams who want visible usage status before long work sessions.

Core promise:

- See remaining AI usage from the macOS menu bar.
- Keep Claude and ChatGPT status in one compact local dashboard.
- Stay local-first: the app reads usage pages in embedded WebKit sessions and does not require a hosted account.

Boundaries:

- Token Monitor is not affiliated with Anthropic, OpenAI, or Apple.
- Usage pages can change; parser fixes may be required after provider UI changes.
- Preview builds may show Gatekeeper warnings until Developer ID signing and notarization are configured.

## Direct Distribution Listing

Title:

```text
Token Monitor for macOS
```

Short description:

```text
A local menu bar monitor for Claude, ChatGPT, and Codex usage limits.
```

Long description:

```text
Token Monitor keeps your Claude, ChatGPT, and Codex usage status visible from the macOS menu bar. It shows remaining quota, reset times, and account status in a compact native dashboard so you can check capacity before starting a long AI work session.

The app runs locally on your Mac. Provider login sessions stay in local WebKit storage, and debug reports are opt-in drafts so you can review private details before sharing anything.

Token Monitor is distributed as a DMG. Preview builds may require the macOS "Open Anyway" flow until Developer ID signing and notarization are configured.
```

SEO title:

```text
Token Monitor for macOS - Claude, ChatGPT, and Codex Usage in the Menu Bar
```

SEO description:

```text
Track Claude, ChatGPT, and Codex usage limits from a compact local macOS menu bar app. See remaining quota, reset times, and stale login states without opening multiple dashboards.
```

Suggested tags:

```text
macOS, menu bar, Claude, ChatGPT, Codex, AI tools, usage monitor, quota tracker, local app
```

## Mac App Store Draft Metadata

Use only if a Mac App Store track is approved after the feasibility work in `docs/apple-distribution-readiness.md`.

App name:

```text
Token Monitor
```

Subtitle:

```text
AI usage in your menu bar
```

Promotional text:

```text
Check Claude, ChatGPT, and Codex usage status from one compact macOS menu bar dashboard.
```

Description:

```text
Token Monitor helps AI power users keep usage limits visible while they work. Open the menu bar dashboard to see remaining Claude, ChatGPT, and Codex capacity, reset times, and connection status in one place.

The app runs locally on your Mac and uses embedded WebKit sessions for provider login pages. It does not require a hosted Token Monitor account. Debug reports are opt-in drafts that you can review before sharing.

Token Monitor is an independent utility and is not affiliated with Anthropic, OpenAI, or Apple. Provider usage pages can change, and parser updates may be required when those layouts change.
```

Keywords:

```text
Claude,ChatGPT,Codex,AI,usage,quota,monitor,menubar
```

Support URL:

```text
https://github.com/MediaPublishing/token-monitor/blob/main/SUPPORT.md
```

Marketing URL:

```text
https://mediapublishing.github.io/token-monitor/
```

Privacy URL:

```text
https://github.com/MediaPublishing/token-monitor/blob/main/docs/privacy.md
```

Review notes draft:

```text
Token Monitor is a local macOS menu bar utility that displays usage status from Claude, ChatGPT, and Codex account pages after the user signs in through embedded WebKit sessions.

The app does not provide a hosted account service. Provider sessions are stored locally by WebKit. Debug reporting is opt-in and opens drafts for user review before anything is shared.

Reviewer testing requires accounts that can access the relevant provider usage pages. If no provider account is connected, the app shows connection-required states.
```

Privacy label draft:

```text
Data collection: None by Token Monitor server infrastructure.
Local data: Provider login sessions, snapshots, and diagnostics can be stored locally on the user's Mac.
Third-party data: The app displays usage information from Claude, ChatGPT, and Codex pages after user login.
Tracking: No tracking by Token Monitor.
Diagnostics: Opt-in draft reports only; users review content before sending or posting.
```

## Screenshot Inventory

Current repo assets:

- `assets/screenshots/app/dashboard.png`: combined Claude and ChatGPT dashboard.
- `assets/screenshots/app/claude.png`: Claude usage detail view.
- `assets/screenshots/app/chatgpt.png`: ChatGPT usage detail view.
- `assets/screenshots/install/gatekeeper-blocked.png`: unsigned preview build warning.
- `assets/screenshots/install/gatekeeper-privacy-security.png`: Privacy & Security override.
- `assets/screenshots/install/gatekeeper-open-anyway.png`: Open Anyway confirmation.
- `assets/screenshots/install/gatekeeper-admin-confirm.png`: administrator password confirmation.

Before App Store submission:

- Capture App Store-sized screenshots from a signed or MAS-specific build.
- Avoid private account names, chat titles, balances, or unreleased UI.
- Confirm the screenshots match the currently submitted binary.

## Launch Checklist

Before public direct-DMG launch:

1. Run `swift test`.
2. Run `./scripts/build-app.sh`.
3. Run `./scripts/check-apple-distribution.sh`.
4. Confirm Developer ID certificate and notary profile are available.
5. Produce a signed/notarized release with `./scripts/package-release.sh`.
6. Verify Gatekeeper accepts `dist/TokenMonitor.app`.
7. Verify `xcrun stapler validate dist/TokenMonitor-macOS.dmg`.
8. Publish GitHub Release assets.
9. Run `./scripts/verify-public-release.sh <tag> <version> <build>` to verify GitHub Release assets, GitHub Pages, `appcast.xml`, and update ZIP are live.
10. Run `TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 ./scripts/verify-public-release.sh <tag> <version> <build>` after Developer ID signing is configured to verify the published DMG with Gatekeeper and stapler.
11. Smoke-test install, launch at login, Claude login, ChatGPT login, and Sparkle update check.

Before Mac App Store submission:

1. Decide whether the MAS track is approved despite Sparkle and WebKit-review risks.
2. Create a MAS build without Sparkle updates.
3. Enable and test App Sandbox entitlements.
4. Fill App Store metadata from this file.
5. Complete privacy labels with final legal/human approval.
6. Attach screenshots captured from the submitted binary.
7. Add reviewer notes and a test-account plan.
8. Submit only after Account Holder approval.

## Approval Gates

Human approval required:

- Paid ads or launch spend.
- App Store submission.
- App privacy labels.
- Public security, privacy, notarization, or compatibility claims.
- Any public support response that references user-provided debug data.

Allowed without extra approval:

- README consistency updates.
- Landing page copy updates that do not add new claims.
- GitHub Release notes for already verified changes.
- Sanitized issue triage and parser fix summaries.
