# App Store Connect Identity Checklist

Last reviewed: 2026-05-13

## Purpose

This checklist keeps the App Store Connect app identity separate from build signing, upload credentials, screenshots, and legal approval.

Run the checker before creating the App Store Connect record or uploading a Mac App Store package:

```bash
./scripts/check-app-store-identity.sh --require-ready
```

## Current Technical Identity

These values come from `Sources/TokenMonitorApp/Resources/Info.plist`:

| Field | Current value |
| --- | --- |
| App name | `Token Monitor` |
| Bundle ID | `com.mediapublishing.tokenmonitor` |
| App Store category | `public.app-category.productivity` |
| Minimum macOS version | `14.0` |
| Version | `1.0.25` |
| Build | `26` |

## Values That Need Human Approval

Before setting strict approval flags, the Account Holder or approved App Store operator must confirm:

- The Apple Developer Team ID owns the app record.
- The Bundle ID is final and not already used by another app.
- The App Store Connect SKU is final.
- The App Store category is final.

Strict approval flags:

```bash
TOKEN_MONITOR_APP_STORE_TEAM_APPROVED=1
TOKEN_MONITOR_APP_STORE_BUNDLE_ID_APPROVED=1
TOKEN_MONITOR_APP_STORE_SKU_APPROVED=1
TOKEN_MONITOR_APP_STORE_CATEGORY_APPROVED=1
```

Values required by the strict checker:

```bash
TOKEN_MONITOR_APP_STORE_TEAM_ID="<TEAMID>"
TOKEN_MONITOR_APP_STORE_SKU="<sku>"
```

## App Store Connect Record Creation Notes

- Do not create the record under the wrong Apple Developer team.
- Do not paste Apple ID passwords, app-specific passwords, API private keys, or `.p12` files into tickets, chat, docs, or commits.
- Keep the SKU stable once the App Store Connect record is created.
- If the Bundle ID changes, rebuild the submitted binary and re-run all MAS checks.
- If the category changes, update the Info.plist and this checklist before submission.

## Related Gates

- Technical MAS readiness: `./scripts/check-mas-readiness.sh`
- Upload package readiness: `./scripts/check-app-store-upload-readiness.sh --require-ready`
- App Store human gates: `./scripts/check-app-store-submission-gates.sh --require-human-gates`
- Publication/legal gates: `./scripts/check-publication-legal-gates.sh --require-legal-gates`
