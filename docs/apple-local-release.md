# Local Developer ID Releases

The release Mac holds the Developer ID private key and the `token-monitor-notary`
credential profile in its login keychain. Neither is exported to GitHub. The
existing Sparkle keychain account `token-monitor` signs automatic updates.

## Completion Scope

Reto confirmed on 2026-11-11 that commissioned Token Monitor fixes include the
complete release by default after appropriate verification: version/build,
tests, existing Developer ID signing and Apple notarization, GitHub release
and Sparkle feed, both download/landing pages, safe local installation, and a
short customer-message draft with the verified download link. Do not stop at
a tested commit or ask again for these routine steps. Respect explicit
exceptions, real blockers and separate boundaries for new credentials,
permissions, costs, App Store submission or sending customer messages.

Only release artifacts go to Apple's existing notary service. Never export
private keys, provider data or credentials. Keep the previous accepted release
and local bundle as rollback sources; verify public downloads before claiming
completion. The message is a draft only, never sent automatically.

## Release Steps

1. Increase the app version/build and update download links and release notes.
2. Run tests and build with the Developer ID identity for team F7ZC4PZ39V in a
   fresh `TOKEN_MONITOR_DIST_DIR`. Preserve the installed app and prior artifacts.
3. Confirm the commissioned release is within the existing authorization
   above; a new authorization is needed for uploads outside that scope. Run `package-release.sh
   --require-distribution-ready` with the existing local identity/profile and
   `TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1`. Do not pass credentials in arguments.
4. Require Apple Accepted for both app and DMG, stapled tickets, and Gatekeeper
   acceptance. Do not rerun packaging against a directory with existing receipts.
   If Apple is still processing, retain the submission ID and wait; do not submit
   duplicate artifacts just because the wait timed out.
5. Stage `TokenMonitor-macOS.dmg`, `TokenMonitor-macOS.zip`, the versioned update
   ZIP from `updates/`, and `appcast.xml` together in one verification directory.
   Run `python3 scripts/verify-signed-release.py <directory>` with normal macOS
   certificate access. This verifies the Sparkle signature, versions, team,
   runtime, notarization, and matching apps in the DMG and both ZIPs.
6. Obtain independent Prover and Checker acceptance. Publish those four exact
   files as GitHub release assets. Include `<!-- token-monitor:prebuilt-notarized -->`
   in the release notes so the release workflow verifies and deploys those assets
   instead of rebuilding them without the local Apple key. For a retry, dispatch
   the release workflow with the tag and `publish_prebuilt_signed=true`.
7. Verify the workflow, public downloads, live appcast, and both landing pages.
   Preserve the previous release as the rollback source.

The old CI signing path remains available only if a separately authorized
credential export is set up in the future. This local release does not configure
such an export or change repository secrets. The Mac App Store is a separate track.
