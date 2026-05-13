# MAS Sandbox Smoke Test Receipt

Use this receipt after running `docs/mas-sandbox-smoke-test.md` on the exact Mac App Store binary intended for upload.

Do not store private account data in this file. Keep screenshots local unless they are sanitized and approved for sharing.

## Build

```text
App version:
Build number:
Bundle ID:
MAS app path:
MAS pkg path:
Apple Distribution identity:
Installer distribution identity:
Test Mac:
macOS version:
Tester:
Date:
```

## Required Command Evidence

```text
./scripts/verify-mas-build.sh --require-apple-distribution:
./scripts/check-mas-readiness.sh:
./scripts/package-mas-pkg.sh:
./scripts/check-app-store-upload-readiness.sh --require-ready:
```

## Manual Test Results

| Area | Result | Evidence reference |
| --- | --- | --- |
| First launch | pass/fail | |
| No-session state | pass/fail | |
| App Store update copy | pass/fail | |
| Claude login | pass/fail | |
| Claude refresh | pass/fail | |
| ChatGPT login | pass/fail | |
| ChatGPT refresh | pass/fail | |
| Relaunch persistence | pass/fail | |
| Debug mode off | pass/fail | |
| Debug GitHub draft | pass/fail | |
| Debug email draft | pass/fail | |
| Launch at Login | pass/fail | |
| Local snapshot storage | pass/fail | |

## Privacy Review

```text
Screenshots contain no personal email addresses: yes/no
Screenshots contain no chat titles: yes/no
Screenshots contain no cookies, tokens, or debug dumps: yes/no
Screenshots contain no private billing details: yes/no
Reviewer accounts are not personal accounts: yes/no
```

## Known Provider Limitations

```text
Claude:
ChatGPT:
Other:
```

## Submission Decision

```text
All required checks passed: yes/no
Screenshots captured from submitted binary: yes/no
Privacy labels still match observed app behavior: yes/no
Reviewer notes still match observed app behavior: yes/no
Approved by Account Holder: yes/no
Decision:
```
