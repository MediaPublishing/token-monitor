# App Store Screenshot Checklist

Last reviewed: 2026-05-13

## Purpose

Use this checklist before uploading Token Monitor screenshots to App Store Connect.
Screenshots must come from the exact MAS binary intended for submission, not from a direct-DMG build or old release.

## Apple Mac Screenshot Requirements

For Mac apps, Apple currently requires:

- 1 to 10 screenshots.
- `.png`, `.jpg`, or `.jpeg` files.
- 16:10 aspect ratio.
- One of these Mac screenshot sizes:
  - `1280 x 800`
  - `1440 x 900`
  - `2560 x 1600`
  - `2880 x 1800`

App previews are optional. If provided for macOS, they must be landscape.

## Token Monitor Screenshot Set

Capture these from the submitted MAS binary:

1. Main dashboard with sanitized Claude and ChatGPT data.
2. Settings view with Launch at Login visible.
3. Connection-required state for Claude and ChatGPT.
4. Optional debug-mode view where draft reporting is visible but no private page text is shown.
5. Optional menu bar status view if it is readable at the chosen Mac screenshot size.

## Privacy Rules

Do not include:

- Email addresses.
- Chat titles.
- Private usage balances, budgets, billing values, or invoices.
- Access tokens, cookies, raw debug dumps, or local file paths containing names.
- Apple ID, App Store Connect, certificate, or GitHub Secret values.
- Browser chrome or unrelated apps.

Use sanitized reviewer accounts where possible. If real usage values appear, crop or recapture the screenshot before upload.

## Folder Convention

Recommended local working folder:

```text
dist/app-store/screenshots/
```

Recommended filenames:

```text
01-dashboard-2880x1800.png
02-settings-2880x1800.png
03-connect-required-2880x1800.png
04-debug-draft-2880x1800.png
05-menu-bar-2880x1800.png
```

Do not commit App Store screenshots unless they are sanitized and intentionally approved for public use.

## Approval Gate

Before setting `TOKEN_MONITOR_APP_STORE_SCREENSHOTS_APPROVED=1`, confirm:

- Screenshots came from the submitted MAS binary.
- Image dimensions match one of Apple's Mac screenshot sizes.
- No private data or credentials are visible.
- Text and UI match the current version submitted for review.
- Account Holder or approved reviewer accepts the screenshot set.

## Source References

- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Apple upload app previews and screenshots: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
