# App Store Review Risk Register

Last reviewed: 2026-05-13

## Purpose

Use this file before a Mac App Store submission or App Review response.
It turns the known Token Monitor review risks into concrete mitigations, evidence, and draft response language.

This is not approval to submit. Account Holder approval and legal/privacy review remain required.

## Submission Rule

Do not submit or reply to App Review until these sources agree with the submitted binary:

- `docs/app-store-submission-packet.md`
- `docs/app-store-privacy-labels.md`
- `docs/mas-sandbox-smoke-test.md`
- `docs/mas-sandbox-smoke-test-receipt.md`
- `docs/publication-legal-checklist.md`

Run the strict gates when the signed MAS binary and human approvals exist:

```bash
./scripts/preflight-mas-submission.sh
./scripts/check-app-store-upload-readiness.sh --require-ready
./scripts/check-app-store-submission-gates.sh --require-human-gates
./scripts/check-publication-legal-gates.sh --require-legal-gates
```

## Risk Register

| Risk | Why it matters | Mitigation before submission | Evidence to attach or cite |
| --- | --- | --- | --- |
| Embedded provider login pages | Review may ask why the app opens third-party login pages in WebKit. | Reviewer notes must explain that users initiate login, provider pages are controlled by their providers, and sessions stay in local WebKit storage. | `docs/app-store-submission-packet.md`, `docs/app-store-privacy-labels.md`, `docs/mas-sandbox-smoke-test-receipt.md` |
| Third-party usage-page parsing | Review may question whether the app scrapes or depends on provider web layouts. | Describe Token Monitor as a local read-only utility that displays account usage pages after user login and may show stale/auth-required states when provider layouts change. | App description, reviewer notes, sandbox smoke test result |
| No hosted account service | Review may expect a Token Monitor account or server-side login. | State clearly that the app has no hosted Token Monitor account service and does not collect usage data through Token Monitor infrastructure. | Privacy labels, privacy URL, reviewer notes |
| Sparkle in App Store build | App Store apps must update through the Mac App Store, not Sparkle. | Submit only the MAS build path and verify no Sparkle framework, binary link, update UI, or `SU*` Info.plist keys are present. | `./scripts/verify-mas-build.sh --require-apple-distribution`, MAS screenshot of update copy |
| App Sandbox behavior | WebKit storage, local snapshots, diagnostics, and Launch at Login can behave differently in sandbox. | Run the MAS sandbox smoke test on the exact submitted binary. | Completed `docs/mas-sandbox-smoke-test-receipt.md` |
| Reviewer account access | Reviewers may not be able to see usage pages without valid provider accounts. | Provide reviewer-safe accounts or a written test plan that shows connection-required states and explains provider account requirements. | Reviewer Test Plan in `docs/app-store-submission-packet.md` |
| Privacy labels | Local provider sessions and diagnostics can be misunderstood as collection. | Keep labels focused on Token Monitor server collection: no server-side collection, no tracking, local WebKit/session/snapshot storage only. | `docs/app-store-privacy-labels.md` and final App Store Connect answers |
| Debug reporting | Debug drafts could contain account-specific UI text if the user submits them. | Keep debug mode off by default and state that reports open as user-reviewed drafts before sharing. | Settings screenshot, reviewer notes, privacy copy |
| Launch at Login | App Review may question login-item behavior or sandbox compatibility. | Make the setting user-controlled, test under sandbox, and include guidance in reviewer notes if needed. | Smoke-test receipt and Settings screenshot |

## Draft Response Snippets

Use these only after confirming they match the submitted binary.

### Embedded WebKit Login

```text
Token Monitor opens Claude, ChatGPT, and Codex provider pages in embedded WebKit sessions only after the user chooses to connect a provider. The app does not collect provider credentials or provide a hosted account service. Provider sessions are stored locally by WebKit on the user's Mac.
```

### Third-Party Usage Pages

```text
Token Monitor is a local read-only menu bar utility. After the user signs in to a provider, it displays usage information from that provider's account pages. If a provider changes its page layout or a session expires, the app shows stale or authentication-required states instead of sending account data to Token Monitor infrastructure.
```

### Updates In The MAS Build

```text
The submitted Mac App Store build does not include Sparkle update functionality. Updates for this build are delivered through the Mac App Store. The direct DMG build is a separate distribution track.
```

### Privacy Labels

```text
Token Monitor does not collect usage data, diagnostics, screenshots, or account information through Token Monitor server infrastructure. Provider login sessions, last-known snapshots, settings, and opt-in diagnostics are stored locally on the user's Mac.
```

### Reviewer Accounts

```text
Reviewer testing requires provider accounts that can access the relevant Claude, ChatGPT, and Codex usage pages. If no provider account is connected, Token Monitor shows connection-required states and remains usable as a local menu bar app awaiting provider login.
```

## If App Review Rejects

1. Do not change App Store Connect metadata, privacy labels, screenshots, or binaries without Account Holder approval.
2. Save the rejection text in a private project note, not in a public issue if it includes reviewer credentials or private account data.
3. Classify the rejection:
   - binary behavior issue
   - metadata or privacy-label mismatch
   - reviewer-account/testability issue
   - third-party-login or WebKit concern
   - update mechanism concern
4. Re-run the matching evidence:
   - `./scripts/verify-mas-build.sh --require-apple-distribution`
   - `./scripts/check-app-store-metadata.sh`
   - `./scripts/check-app-store-screenshots.sh --require-ready`
   - `./scripts/check-app-store-submission-gates.sh --require-human-gates`
5. Update the reviewer notes or binary only after the evidence shows the actual issue.
6. Keep direct Developer ID DMG distribution available as the fallback path if MAS review risk is too high.
