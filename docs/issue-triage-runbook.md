# Issue Triage Runbook

Last reviewed: 2026-05-13

## Purpose

Use this runbook for public Token Monitor bug reports after a GitHub Release, Sparkle update, or Mac App Store review build.
It keeps parser, install, update, Gatekeeper, Launch at Login, and debug-report issues moving without exposing private account data.

## Public Issue Rules

GitHub Issues are public.
Do not ask users to attach raw debug dumps, screenshots with private account data, chat titles, usage budgets, balances, email addresses, access tokens, cookies, Apple credentials, certificates, private keys, `.p12` files, or GitHub Secrets.

Use private vulnerability reporting for:

- leaked credentials
- raw private debug dumps
- signing/notarization secrets
- Apple account or App Store Connect credential exposure
- security vulnerabilities

Use public issue forms only for sanitized reports:

- `.github/ISSUE_TEMPLATE/parser-layout-bug.yml`
- `.github/ISSUE_TEMPLATE/install-update-bug.yml`

## GitHub Label Setup

The issue templates rely on these repository labels:

- `parser`
- `install`
- `needs-triage`

Verify them after repository setup or label cleanup:

```bash
./scripts/check-github-issue-labels.sh
```

## Intake Checklist

For every public issue:

1. Confirm the report contains no private data.
2. Confirm Token Monitor version and build.
3. Identify the affected path:
   - Claude parser
   - ChatGPT parser
   - install or Gatekeeper
   - Sparkle update
   - Launch at Login
   - debug report draft
   - Mac App Store or TestFlight track
4. Confirm whether the issue affects the current public release tag.
5. Label or classify the issue before asking for more data.
6. Ask only for sanitized percentages, visible labels, reset text, account language/locale, macOS version, and screenshots with private data hidden.

## Parser/Layout Bugs

Use this workflow when Claude, ChatGPT, or Codex usage values are wrong, stale, missing, or unparseable:

1. Reproduce from sanitized visible text, a redacted fixture, or a locally captured debug record.
2. Add or update a focused parser test before changing parser logic.
3. Make missing or provider-specific metric blocks optional when the rest of the page is parseable.
4. Preserve last-known-good snapshots when a provider layout is unsupported.
5. Verify dashboard progress and reset labels still display safely.
6. Run:

```bash
swift test --filter ClaudeUsageParserTests
swift test --filter ChatGPTUsageParserTests
swift test --filter DashboardReducerTests
```

Use the smaller relevant subset first, then rely on full CI after push.

## Install, Gatekeeper, And Update Bugs

Use this workflow for DMG install, Gatekeeper, Sparkle, Launch at Login, or release-channel issues:

1. Confirm install source:
   - GitHub Release DMG
   - Sparkle update
   - local source build
   - Mac App Store or TestFlight
2. Confirm whether the user is on a signed/notarized build or an unsigned preview build.
3. Verify the current public release and release channel:

```bash
./scripts/check-public-distribution-urls.sh
./scripts/check-github-release-channel.sh
./scripts/verify-public-release.sh <tag> <version> <build>
```

4. If signing/notarization is involved, do not claim the Gatekeeper warning is fixed until Developer ID signing and notarization pass:

```bash
./scripts/check-apple-distribution.sh --require-ready
TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 ./scripts/verify-public-release.sh <tag> <version> <build>
```

5. For Launch at Login issues, check whether the app was moved to `/Applications` and whether the build is properly signed.

## Public Reply Template

```text
Thanks. Please do not attach raw debug dumps or screenshots with private account data.

For this issue, sanitized visible labels are enough:
- Token Monitor version/build
- macOS version
- provider
- account language/locale
- visible percentage values
- visible reset labels
- whether the card says Healthy, Stale, or Auth Required

If a screenshot is needed, hide email addresses, chat titles, balances, budgets, and any billing details first.
```

## Private Report Redirect Template

```text
This looks like it may include private account data or credentials, so please do not post details in this public issue.

Use GitHub private vulnerability reporting for the sensitive part, or open a minimal public issue that only says a private report is needed.
```

## Hotfix Release Path

Use this only when the active public release is broken for users:

1. Confirm the issue affects the current public release.
2. Add a regression test or release verifier before the fix when practical.
3. Fix the smallest affected surface.
4. Run the focused local tests or script checks.
5. Push to `main` and wait for CI.
6. Prepare a new patch version.
7. Publish only through the Release workflow.
8. Verify after publishing:

```bash
./scripts/check-public-distribution-urls.sh
./scripts/check-github-release-channel.sh
./scripts/verify-public-release.sh <tag> <version> <build>
```

For signed public releases after Developer ID access exists, also run:

```bash
TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 ./scripts/verify-public-release.sh <tag> <version> <build>
```

## Closeout Checklist

Before closing an issue:

- The fix is merged to `main`.
- CI passed for the fixing commit.
- Any new public release is verified.
- The public reply contains only sanitized details.
- Private debug data, if used, was not committed or copied into public comments.
- Follow-up release or support docs are linked if needed.
