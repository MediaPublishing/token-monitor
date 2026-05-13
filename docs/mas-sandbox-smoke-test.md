# Token Monitor MAS Sandbox Smoke Test

Last reviewed: 2026-05-13

## Purpose

Use this checklist before Mac App Store upload, after the MAS binary has been built with an `Apple Distribution` identity and verified with:

```bash
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
./scripts/preflight-mas-submission.sh
```

This is a manual test because WebKit provider login, Launch at Login, local snapshots, and debug-draft behavior cannot be proven by static checks alone.

## Preconditions

- Use the exact MAS binary intended for App Store submission.
- Use reviewer-safe Claude and ChatGPT accounts. Do not use personal accounts.
- Do not capture private emails, chat titles, access tokens, cookies, billing pages, or raw debug dumps in evidence.
- Confirm `./scripts/verify-mas-build.sh --require-apple-distribution` passed for the same app bundle.
- Confirm `./scripts/check-mas-readiness.sh` reported zero static blockers.

## Pass Criteria

All required checks below must pass. If any required check fails, do not submit the build.

| Area | Steps | Expected result | Evidence |
| --- | --- | --- | --- |
| First launch | Install and launch the MAS build from a clean user session. | Token Monitor opens as a menu bar app without Sparkle update UI. | Screenshot of connection-required dashboard. |
| No-session state | Open the menu bar dashboard before provider login. | Claude and ChatGPT show connection-required or reconnect states, not stale private data. | Screenshot with no private account data. |
| App Store update copy | Open Settings. | Update copy refers to Mac App Store updates, not Sparkle. | Settings screenshot. |
| Claude login | Connect Claude with the reviewer-safe account. | Login completes or fails with a clear provider/auth state. | Screenshot of healthy, stale, or auth-required Claude card. |
| Claude refresh | Run manual refresh. | Claude metrics update or retain a last-known snapshot with a clear stale reason. | Screenshot after refresh. |
| ChatGPT login | Connect ChatGPT with the reviewer-safe account. | Login completes or fails with a clear provider/auth state. | Screenshot of healthy, stale, or auth-required ChatGPT card. |
| ChatGPT refresh | Run manual refresh. | ChatGPT metrics update or retain a last-known snapshot with a clear stale reason. | Screenshot after refresh. |
| Relaunch persistence | Quit and relaunch Token Monitor. | WebKit sessions and last-known snapshots behave consistently after relaunch. | Before/after note in release checklist. |
| Debug mode off | With debug mode disabled, trigger a refresh. | No report draft is created automatically. | Note in release checklist. |
| Debug GitHub draft | Enable debug mode and open a GitHub Issue draft. | A draft opens for review; raw private debug dumps are not posted automatically. | Screenshot of draft review step with private data hidden. |
| Debug email draft | Enable debug mode and open an email draft. | A draft opens for review; nothing sends automatically. | Screenshot of draft review step with private data hidden. |
| Launch at Login | Toggle Launch at Login off and on. Relaunch macOS user session if practical. | Login Item state changes as expected under App Sandbox. | Screenshot or note from macOS Login Items. |
| Local snapshot storage | Refresh, quit, relaunch, and inspect dashboard. | Last-known usage data is available or a clear empty/auth-required state is shown. | Before/after note in release checklist. |

## Fail Conditions

Do not upload the MAS build if any of these occur:

- Sparkle UI or Sparkle update keys appear in the submitted build.
- Provider login opens unexpected external browser windows without user action.
- Debug reports are sent automatically without user review.
- Raw debug dumps, cookies, access tokens, chat titles, or private billing details appear in public drafts.
- Launch at Login cannot be toggled or behaves unpredictably under App Sandbox.
- The app crashes during provider login, manual refresh, or relaunch.

## Reviewer Account Notes

- Reviewer accounts should have access to the provider usage pages the parser reads.
- If Claude or ChatGPT blocks embedded WebKit login for review accounts, document the exact user-facing state and include reviewer notes explaining the limitation.
- If a provider layout changes during review, the submitted build should show a clear stale or parser-warning state rather than crashing.

## Completion Record

Copy `docs/mas-sandbox-smoke-test-receipt.md` for the final test run and record the result before upload:

```text
Build:
Tester:
Date:
Claude account type:
ChatGPT account type:
All required checks passed: yes/no
Known provider limitations:
Screenshots captured from submitted binary: yes/no
Approved by Account Holder: yes/no
```
