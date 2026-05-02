# Token Monitor App Store Submission Packet

Last reviewed: 2026-05-02

## Purpose

This packet collects the App Store Connect material that can be prepared before Apple Developer access exists. It is a draft, not approval to submit.

Use it only after the Mac App Store track is explicitly approved and the submitted binary is built from the MAS build path.

## Submission Gates

Do not submit until all are true:

1. Account Holder approves Mac App Store submission.
2. Apple Developer Program and App Store Connect access are available.
3. Agreements, tax, and banking are complete in App Store Connect.
4. `scripts/build-mas-app.sh` builds the submitted binary.
5. `scripts/verify-mas-build.sh` passes for the submitted binary.
6. `scripts/check-mas-readiness.sh` reports zero blockers.
7. A sandbox smoke test passes for login, refresh, local snapshots, diagnostics, and Launch at Login.
8. Screenshots are captured from the submitted binary and contain no private account data.
9. Privacy labels and the privacy policy receive final human/legal approval.
10. Reviewer notes and test accounts are approved by the Account Holder.

## App Metadata Draft

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

## Privacy Label Draft

Final answers must be reviewed in App Store Connect before submission.

Data collected by Token Monitor server infrastructure:

```text
None.
```

Tracking:

```text
No. Token Monitor does not track users across apps or websites.
```

Local app data:

```text
Provider login sessions are stored locally by WebKit on the user's Mac. Last-known usage snapshots, app settings, and opt-in diagnostic files can be stored locally in the user's macOS Library.
```

Third-party provider data:

```text
After user login, the app displays usage information from Claude, ChatGPT, and Codex account pages. Those provider pages and login flows are controlled by the respective third parties.
```

Diagnostics:

```text
Debug mode is off by default. When enabled, Token Monitor can prepare GitHub Issue or email report drafts for the user to review before sharing.
```

## Reviewer Notes Draft

```text
Token Monitor is a local macOS menu bar utility that displays usage status from Claude, ChatGPT, and Codex account pages after the user signs in through embedded WebKit sessions.

The app does not provide a hosted Token Monitor account service. Provider sessions are stored locally by WebKit. Usage snapshots and debug diagnostics are stored locally on the user's Mac.

Debug reporting is opt-in. Report actions open drafts for user review before anything is shared.

The Mac App Store build does not include Sparkle. Updates are delivered by the Mac App Store.

If no provider account is connected, the app shows connection-required states. Reviewer testing requires provider accounts that can access the relevant usage pages.
```

## Reviewer Test Plan

Use test accounts created specifically for review. Do not use personal accounts.

1. Install and launch the MAS build.
2. Open the menu bar item and confirm both providers show connection-required states when no session exists.
3. Open Settings and confirm updates are described as Mac App Store updates, not Sparkle updates.
4. Enable and disable Launch at Login, then confirm macOS Login Items behavior.
5. Connect Claude with the reviewer account.
6. Refresh Claude and confirm usage metrics or a clear stale/auth-required state.
7. Connect ChatGPT with the reviewer account.
8. Refresh ChatGPT and confirm usage metrics or a clear stale/auth-required state.
9. Enable debug mode.
10. Run a manual refresh.
11. Open a GitHub Issue draft and confirm the draft can be reviewed before submission.
12. Open an email draft and confirm the draft can be reviewed before sending.
13. Disable debug mode before ending review.

## Screenshot Requirements

Capture screenshots from the exact submitted MAS binary.

Required screenshots:

- Main dashboard with sanitized Claude and ChatGPT data.
- Settings view showing Launch at Login and Mac App Store update copy.
- Connection-required state without private account data.
- Optional debug mode view with no private page text.

Do not include:

- Real email addresses.
- Chat titles.
- Private balances, budgets, or billing details.
- Access tokens, cookies, or debug dumps.
- Browser chrome from unrelated apps.

## Sandbox Smoke Test

Before submission, run the MAS binary and verify:

- WebKit login sessions persist across app relaunch.
- Manual refresh works for connected providers.
- Last-known snapshots persist across app relaunch.
- Debug files are written only after debug mode is enabled.
- Launch at Login can be toggled and behaves as expected.
- App Store update copy is visible instead of Sparkle update controls.
- No Sparkle framework or `SU*` Info.plist keys are present in the submitted app.

## Known Review Risks

- The app reads third-party provider usage pages after user login.
- Provider layouts can change and temporarily break parsing.
- Embedded WebKit login may behave differently from provider-owned browsers.
- Reviewer accounts must have access to provider usage pages.
- Launch at Login behavior must be acceptable under App Sandbox.

## Submission Command Checklist

Run before upload:

```bash
swift test
./scripts/build-mas-app.sh
./scripts/verify-mas-build.sh
./scripts/check-mas-readiness.sh
```

If Apple Distribution signing is configured locally, set:

```bash
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
./scripts/build-mas-app.sh
```

Then re-run:

```bash
./scripts/verify-mas-build.sh
```

## Open Human Decisions

- Whether to submit to the Mac App Store at all.
- Which Apple Developer team owns the app.
- Final app category.
- Final support contact and support SLA.
- Final privacy policy language.
- Final test accounts and reviewer credentials.
- Whether Launch at Login remains enabled in the MAS build.
