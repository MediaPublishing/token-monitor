# App Store Privacy Labels

Last reviewed: 2026-05-13

## Purpose

Use this checklist before answering App Store Connect privacy questions for Token Monitor.
It is a product and engineering draft, not legal approval.

Final App Store privacy answers must be approved by the Account Holder or an approved legal/privacy reviewer before setting:

```text
TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED=1
```

## Current Product Understanding

Token Monitor is designed as a local macOS menu bar utility:

- It does not require a Token Monitor account.
- It does not operate Token Monitor server infrastructure for usage data.
- Provider login sessions are handled by embedded WebKit pages.
- Usage snapshots, settings, and opt-in diagnostics are stored locally on the user's Mac.
- Debug report actions open user-reviewed drafts.
- Public GitHub Issues are user-submitted and must not contain raw debug dumps or private account data.

## Draft App Store Connect Answers

### Data Collection

Draft answer:

```text
No, Token Monitor does not collect data from this app.
```

Rationale:

- Apple defines collection as transmitting data off the device in a way that lets the developer or third-party partners access it beyond what is needed for a real-time request.
- Token Monitor does not send usage data, account data, login sessions, diagnostics, or screenshots to Token Monitor server infrastructure.
- Local WebKit sessions and local snapshots remain on the user's Mac.

Required confirmation before submission:

- No analytics, ads, telemetry, crash-reporting SDK, or remote logging SDK has been added.
- Debug mode still opens drafts only and does not send automatically.
- The MAS binary has no new network endpoint controlled by Token Monitor.
- App Store reviewer accounts and screenshots do not include private real-user data.

### Tracking

Draft answer:

```text
No, Token Monitor does not track users across apps or websites.
```

Required confirmation before submission:

- No advertising SDK or data broker integration exists.
- No Token Monitor identifier is linked with third-party data for advertising or advertising measurement.

### Data Linked To The User

Draft answer:

```text
Not applicable if no data is collected by Token Monitor.
```

Required confirmation before submission:

- Token Monitor does not collect account identifiers, email addresses, usage data, diagnostics, or device identifiers.
- User-submitted GitHub Issues or emails are outside automatic app collection and are user-initiated drafts.

### Third-Party Provider Pages

Clarification for reviewer notes:

```text
Claude, ChatGPT, and Codex login pages are controlled by their respective providers. Token Monitor displays those pages in WebKit after user action. Provider privacy policies apply to those provider sessions.
```

Do not describe provider-side data handling as Token Monitor collection unless Token Monitor transmits or stores it off device.

## App Privacy Links

Privacy Policy URL:

```text
https://github.com/MediaPublishing/token-monitor/blob/main/docs/privacy.md
```

Privacy Choices URL:

```text
Not planned for the initial submission.
```

Before submission, confirm whether `docs/privacy.md` remains the approved public privacy policy URL or whether a formal hosted policy URL should replace it.

## Change Triggers

Reopen privacy-label review if any of these change:

- Automatic diagnostic sending is added.
- Remote analytics, telemetry, crash reporting, or logging is added.
- A hosted Token Monitor account or sync service is added.
- Email reports are sent without opening a user-reviewed draft first.
- GitHub Issues are created automatically without user review.
- Any third-party SDK is added to the MAS binary.
- Any server owned by Token Monitor receives usage, account, device, or diagnostic data.

## Approval Gate

Before setting `TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED=1`, confirm:

- Account Holder or approved reviewer has reviewed this checklist.
- App Store Connect answers match the submitted MAS binary.
- `docs/privacy.md` or the replacement privacy URL is final.
- Screenshot and reviewer test account data are sanitized.
- Public claims in README, landing page, release notes, and App Store metadata match the approved privacy answers.

## Source References

- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple Manage App Privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple App Privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-privacy/
