# Update Checks and Diagnostics

## Expected Behavior from 1.0.41

- Automatic checks remain opt-in and preserve Sparkle's existing saved preference.
- Enabling checks starts a background check immediately when the updater is idle. The default interval is one hour while Token Monitor is running.
- An available update adds `Update` to the menu bar and `Review Update` to the dashboard and Settings header. Scheduled checks do not open an unseen background alert.
- `Review Update` and `Check for Updates...` bring Sparkle's update dialog into focus. Installation remains a separate user choice. The automatic-check switch does not turn on silent installation.
- `Remind Me Later` leaves the in-app reminder available. `Skip This Version` clears it and suppresses scheduled reminders for that version. A manual check can still find a skipped version.
- Updates do not clear provider sessions or rename existing accounts.

## Why Older Versions Could Appear Not to Update

The app used Sparkle's daily default interval. As an `LSUIElement` background app without a user-driver delegate, it also relied on update alerts shown behind other applications. Sparkle logged this exact missing-reminder condition on the local app. Neither finding proves a particular remote machine has no additional network or installation problem.

Primary references for the pinned Sparkle 2.9.1 integration:

- [Gentle reminders for background applications](https://sparkle-project.org/documentation/gentle-reminders/)
- [Update-check settings and interval defaults](https://sparkle-project.org/documentation/customization/)

## Smallest Useful Support Evidence

1. Open Settings and record the version/build shown under Updates.
2. Click `Check for Updates...` and note the exact result or take a screenshot of the error.
3. If it still fails on 1.0.41 or later, create a local Debug Report through an existing draft button. Its `App updates` section contains the running app location, feed URL, automatic-check/download preferences, interval, last/next check, current session, result and error codes. This section is available even with provider debug mode off.
4. Review the draft before sharing. For an update-only problem, share the `App updates` section plus app/macOS version, not the provider page previews. No report is sent automatically.

Older reports do not contain updater diagnostics. An installation error from the manual check is more useful than another provider usage dump. Prefer one app in Applications rather than running a copy from a mounted DMG or keeping several versions open.
