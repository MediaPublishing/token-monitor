# Token Monitor App Store Submission Packet

Last reviewed: 2026-05-13

## Purpose

This packet collects the App Store Connect material that can be prepared before Apple Developer access exists. It is a draft, not approval to submit.

Use it only after the Mac App Store track is explicitly approved and the submitted binary is built from the MAS build path.

## Submission Gates

Do not submit until all are true:

1. Account Holder approves Mac App Store submission.
2. Apple Developer Program and App Store Connect access are available.
3. Agreements, tax, and banking are complete in App Store Connect.
4. `scripts/check-app-store-identity.sh --require-ready` passes before App Store Connect record creation or upload.
5. `scripts/build-mas-app.sh` builds the submitted binary.
6. `scripts/verify-mas-build.sh --require-apple-distribution` passes for the submitted binary.
7. `scripts/package-mas-pkg.sh` produces `dist/mas/TokenMonitor-macOS-AppStore.pkg` with a Mac App Store installer distribution identity.
8. `scripts/check-mas-readiness.sh` reports zero blockers.
9. The sandbox smoke test in `docs/mas-sandbox-smoke-test.md` passes for login, refresh, local snapshots, diagnostics, and Launch at Login.
10. Screenshots are captured from the submitted binary and contain no private account data.
11. `scripts/check-app-store-screenshots.sh --require-ready` passes for the final screenshot folder.
12. Privacy labels and the privacy policy receive final human/legal approval.
13. Reviewer notes and test accounts are approved by the Account Holder.
14. `scripts/check-app-store-submission-gates.sh --require-human-gates` passes with explicit acknowledgements for Account Holder approval, App Store Connect readiness, privacy approval, reviewer plan, screenshots, support URLs, and sandbox smoke testing.
15. `scripts/check-app-store-upload-readiness.sh --require-ready` passes on the upload machine, or the Account Holder confirms upload will happen manually through App Store Connect, Xcode, or Transporter.

## App Metadata Draft

Validate these draft limits before submission:

```bash
./scripts/check-app-store-metadata.sh
```

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
Claude,ChatGPT,Codex,AI tools,usage,quota,monitor,menubar
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

## App Store Connect Identity

Detailed identity approval gates live in `docs/app-store-connect-identity.md`.

Current technical identity:

- App name: `Token Monitor`
- Bundle ID: `com.mediapublishing.tokenmonitor`
- Category: `public.app-category.productivity`
- Minimum macOS version: `14.0`

Before App Store Connect record creation or upload:

```bash
./scripts/check-app-store-identity.sh --require-ready
```

## Privacy Label Draft

Final answers must be reviewed in App Store Connect before submission.

Detailed privacy-label rationale and approval gates live in `docs/app-store-privacy-labels.md`.

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

Detailed capture requirements live in `docs/app-store-screenshot-checklist.md`.

For Mac apps, App Store Connect currently accepts 1 to 10 screenshots in `.png`, `.jpg`, or `.jpeg` format, 16:10 aspect ratio, at one of Apple's Mac screenshot sizes such as `1280 x 800`, `1440 x 900`, `2560 x 1600`, or `2880 x 1800`.

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

Before submission, run the MAS binary through `docs/mas-sandbox-smoke-test.md` and verify:

- WebKit login sessions persist across app relaunch.
- Manual refresh works for connected providers.
- Last-known snapshots persist across app relaunch.
- Debug files are written only after debug mode is enabled.
- Launch at Login can be toggled and behaves as expected.
- App Store update copy is visible instead of Sparkle update controls.
- No Sparkle framework or `SU*` Info.plist keys are present in the submitted app.

Before uploading screenshots, validate file dimensions:

```bash
./scripts/check-app-store-screenshots.sh --require-ready
```

## Known Review Risks

- The app reads third-party provider usage pages after user login.
- Provider layouts can change and temporarily break parsing.
- Embedded WebKit login may behave differently from provider-owned browsers.
- Reviewer accounts must have access to provider usage pages.
- Launch at Login behavior must be acceptable under App Sandbox.

## Submission Command Checklist

Run before upload:

```bash
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
TOKEN_MONITOR_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)" \
./scripts/preflight-mas-submission.sh
```

The preflight runs:

- `swift test`
- `./scripts/check-mas-readiness.sh`
- `./scripts/check-app-store-identity.sh --require-ready`
- `./scripts/build-mas-app.sh`
- `./scripts/verify-mas-build.sh --require-apple-distribution`
- `./scripts/package-mas-pkg.sh`

It does not replace Account Holder approval, App Store Connect setup, privacy-label review, reviewer-account approval, submitted-binary screenshots, or sandbox smoke testing.

Check the upload handoff without uploading anything:

```bash
./scripts/check-app-store-upload-readiness.sh
```

Use strict mode only after the signed MAS package, upload tool, and upload credentials are available on the upload machine:

```bash
./scripts/check-app-store-upload-readiness.sh --require-ready
```

Apple supports uploading builds with Xcode, altool, or Transporter. App Store Connect API keys can be used with Transporter for upload authentication, but the App Store Connect API does not replace the binary upload tool itself.

Run the human gate check before upload:

```bash
TOKEN_MONITOR_APP_STORE_ACCOUNT_HOLDER_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_CONNECT_READY=1 \
TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_SCREENSHOTS_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_SUPPORT_URL_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_SANDBOX_SMOKE_TEST_PASSED=1 \
./scripts/check-app-store-submission-gates.sh --require-human-gates
```

## Open Human Decisions

- Whether to submit to the Mac App Store at all.
- Which Apple Developer team owns the app.
- Final app category.
- Final support contact and support SLA.
- Final privacy policy language.
- Final test accounts and reviewer credentials.
- Whether Launch at Login remains enabled in the MAS build.
