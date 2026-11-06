# Account-specific refresh diagnosis

## Reported symptom

Patrick's screenshot shows ChatGPT and ChatGPT 2 with a usage-layout parse error,
Claude Pat with a parse error and a snapshot 12 hours old, and Claude healthy with
a weekly-only limit. Refresh and restart reportedly do not restore the failed accounts.
The screenshot contains neither the failing page extract nor the installed version.

## What is established

- A parse error is distinct from a timeout or an explicitly detected login requirement.
  It means the extraction did not satisfy the parser's expected usage structure; it
  does not prove that the provider changed its layout or that the session is valid.
- The visible values are retained successful snapshots, not freshly verified values.
- Refresh retries extraction but does not change parsing rules. Repeatedly receiving
  the same unsupported content can therefore fail across refreshes and restarts.
- The 1.0.52 parser change only made Claude's current-session section optional.
  Weekly heading, percentage and reset requirements were unchanged. ChatGPT's parser
  was not changed in that commit. This does not establish a shared 1.0.52 regression.
- The previous diagnostics implementation saved only `<provider>-latest.json`.
  Multiple accounts shared this destination. A successful refresh could overwrite
  another account's failed extract, and there was no account ID in the record.

## Implemented diagnostic correction

Account IDs are passed from SessionCoordinator to both normal and blocked-navigation
records. Diagnostics retain a latest record and a last terminal failure per account.
Success and incidental blocked navigation cannot erase that retained failure.
Reports label account IDs/names, timestamp each entry and warn that retained failures
may predate the current state. Identical latest/failure entries are shown only once.
Existing provider-only records remain readable but are explicitly unattributable.
Debug mode remains opt-in. Both copies use existing redaction and private file modes.
No session, cookie, navigation or parser behavior was changed.

## Verification

- `bash scripts/check-refresh-diagnostics.sh`: before correction, the regression
  failed because success erased a preceding parse failure. After correction, seven
  checks pass: retention, account separation, restart, bounded/redacted/private files,
  debug-off writes, legacy decoding, and blocked-navigation retention.
- Full Swift suite: 165 tests in 19 suites, plus the existing five distribution checks.
- Targeted manual review of the four implementation files and the diagnostic harness.
  Existing untracked layout prototypes are outside this change and remain untouched.

## Remaining evidence needed

Do not claim the provider read failure itself is fixed. Ask for a debug report after
enabling Debugging and refreshing each affected account. Use the debug report / email
draft, not only Save Performance Report (which diagnoses resource consumption).
Inspect URL, page title, body preview and segments for each failed account before
changing parsing. A screenshot of the provider's actual usage page would help confirm
whether the extract represents the same page. Reports may still contain account-specific
page text; review privately before sharing. Do not disconnect/recreate accounts or clear
sessions as an unproven workaround.

## Delivery state

The diagnostic implementation was prepared on `fix/account-refresh-diagnostics`.
The user subsequently requested continuation into release 1.0.53 (62). Its release,
public verification and local installation are tracked in the dated operations receipt.
This is not a confirmed parser fix for Patrick's unknown failing page.
