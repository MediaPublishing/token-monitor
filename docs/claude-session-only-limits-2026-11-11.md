# Claude session-only limits: diagnosis and fix

Date: 2026-11-11
Release target: 1.0.55 (64), on `fix/claude-session-only-limits`.
Live-account confirmation remains outstanding; public release verification is
recorded separately in the 1.0.55 rollout receipt.
Base: `7d19141cad026a507b8561b6dd8838b3beee49af` (release 1.0.54 source).

## Evidence and limits

The privacy-safe report from 1.0.54 shows one stale Claude account with
session heading, percentage and reset recognition, but no weekly markers.
Another Claude account succeeds with weekly-only markers. Both ChatGPT
accounts' latest refreshes succeed; earlier retained failures are historical.
Both successful and failed Claude refreshes have `otherProviderPage`, so
that category alone does not establish incorrect navigation.

Markers are hints, not the original page or proof of authentication. No
private page text, account identifiers, chat titles or credentials were
requested or inspected. This does not establish tariff rules or explain all
historical failures on previously paid accounts.

## Reproduction and cause

Synthetic English and German extracts containing a real session section
and no weekly section throw `unsupportedLayout` in the released parser.
Weekly-only and combined sections succeed. The parser requires a weekly
heading, used percentage and reset before it considers the session.
After retries, the controller records `parseFailure`; the model retains the
old snapshot as stale. Refreshing or restarting cannot correct this input
contract.

A related test reproduces rejection when the page contains a session plus
`This week's usage by product`: substring matching treats explanatory text
as a weekly-limit heading, then fails to find weekly-limit values.

## Correction and acceptance criteria

- Accept session-only, weekly-only and combined observed core limits.
- Require exact weekly headings, not matching words inside explanations.
- Do not invent a weekly metric or menu-bar total from session capacity.
- Continue rejecting an explicitly present but incomplete weekly section;
  retain retries rather than silently discard a partly loaded weekly quota.
- Reject pages without an observed core limit, even if model-specific or
  usage-credit percentages exist.
- Append optional Sonnet metrics safely with either one or two core limits;
  the former fixed insertion index could exceed the array bounds.
- Preserve existing section boundaries, authentication and privacy behavior.

## Verification

- New session-only regression failed before the fix in all three language
  cases, with the same unsupported-layout error.
- Explanation-heading regression failed in all three cases before removing
  substring fallback.
- Standalone synthetic probe: session-only, weekly-only and combined inputs
  now succeed with exactly their observed core metrics.
- Full `swift test` with macOS 26.5 SDK: 172 tests in 19 suites pass,
  including 5 distribution checks run by the suite.
- `bash scripts/check-refresh-diagnostics.sh`: all 10 privacy checks pass.
- `git diff --check`: passes. Targeted manual review covers only parser and
  regression changes; unrelated pre-existing prototype files are untouched.
- No production accounts, cookies, app installation, signing, release feed
  or public download files changed. Live confirmation remains outstanding.

## Bounded retrospective

Previous coverage tested weekly-only limits but not the inverse session-only
case. The selected improvement is the six focused regression tests in the
existing Claude parser suite, covering both absent and incomplete quotas.
No additional logging or private diagnostic fields are needed for this fix.
