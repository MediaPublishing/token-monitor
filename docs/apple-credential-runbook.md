# Apple Credential Runbook

Last reviewed: 2026-05-13

This runbook explains how to prepare Token Monitor for Developer ID signing and notarization without putting Apple credentials into chat, source files, or release artifacts.

Access role and invitation guidance lives in `docs/apple-access-handoff.md`.

## Required Access

Human account holder or admin setup:

- Active Apple Developer Program membership.
- Access to Certificates, Identifiers & Profiles.
- Permission to create a Developer ID Application certificate.
- Permission to create an app-specific password for notarization.
- Permission to add GitHub repository secrets.

Do not share Apple ID passwords, certificate passwords, or app-specific passwords in chat.

## Create Developer ID Certificate

1. Open Apple Developer Certificates, Identifiers & Profiles.
2. Create a `Developer ID Application` certificate.
3. Use Keychain Access on the release Mac to create or import the certificate.
4. Export the certificate and private key from Keychain Access as a `.p12`.
5. Protect the `.p12` with a strong password.

Keep the `.p12` outside the repo.

## Encode Certificate For GitHub Actions

Run locally on the release Mac:

```bash
base64 -i /path/to/DeveloperIDApplication.p12 -o /tmp/token-monitor-developer-id.p12.base64
pbcopy < /tmp/token-monitor-developer-id.p12.base64
```

Paste the clipboard value into the GitHub secret:

```text
TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64
```

Then remove the temporary encoded file:

```bash
trash /tmp/token-monitor-developer-id.p12.base64
```

If `trash` is not installed, move the file to the macOS Trash manually. Do not commit it.

## GitHub Secrets

Configure these repository secrets:

```text
TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64
TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_PASSWORD
TOKEN_MONITOR_CODESIGN_IDENTITY
TOKEN_MONITOR_RELEASE_KEYCHAIN_PASSWORD
TOKEN_MONITOR_NOTARY_APPLE_ID
TOKEN_MONITOR_NOTARY_TEAM_ID
TOKEN_MONITOR_NOTARY_APP_PASSWORD
SPARKLE_PRIVATE_KEY
```

Notes:

- `TOKEN_MONITOR_CODESIGN_IDENTITY` must match the exact Keychain identity, for example `Developer ID Application: Example Name (TEAMID)`.
- `TOKEN_MONITOR_RELEASE_KEYCHAIN_PASSWORD` is optional. If it is missing, the GitHub workflow creates a temporary password.
- `SPARKLE_PRIVATE_KEY` is required for appcast signing.

Verify the repository secret names without exposing any secret values:

```bash
./scripts/check-github-release-secrets.sh
```

After Developer ID access exists, make the check fail if signing or notarization secrets are missing:

```bash
./scripts/check-github-release-secrets.sh --require-signing-secrets
```

## GitHub Repository Variables

For signed GitHub Release workflow runs, configure these non-secret repository variables after the Account Holder has approved the direct Developer ID path:

```text
TOKEN_MONITOR_APPLE_TEAM_ID
TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY=1
TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED=1
TOKEN_MONITOR_DIRECT_DMG_APPROVED=1
TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED=1
TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED=1
TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED=1
```

The `Release` workflow runs `./scripts/check-apple-access-handoff.sh --require-direct-dmg-access` when Developer ID signing is required or signing secrets are present. This prevents a signed/notarized release from being produced before the non-secret Apple access handoff has been acknowledged.

Verify those repository variables without exposing any secret values:

```bash
./scripts/check-github-release-variables.sh --require-direct-dmg-variables
```

Optional preview override:

```text
TOKEN_MONITOR_ALLOW_UNSIGNED_PREVIEW_RELEASES=1
```

Use this only for explicit preview distribution before Developer ID credentials exist. Normal public releases should be Developer ID signed and notarized. The `Release` workflow refuses unsigned normal releases unless the GitHub Release is marked as a prerelease or the manual workflow input `allow_unsigned_preview` is enabled.

## Mac App Store Certificates

The Mac App Store track needs separate signing identities from the direct Developer ID DMG path:

- `Apple Distribution: <Name> (<TEAMID>)` signs the MAS app bundle.
- `3rd Party Mac Developer Installer: <Name> (<TEAMID>)` or `Mac Installer Distribution: <Name> (<TEAMID>)` signs the upload package.

Use these only for the MAS build track:

```bash
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)" \
TOKEN_MONITOR_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)" \
./scripts/preflight-mas-submission.sh
```

The MAS package script writes:

```text
dist/mas/TokenMonitor-macOS-AppStore.pkg
```

## App Store Connect Upload Credentials

Do not store App Store Connect API private keys, Apple ID passwords, app-specific passwords, or Transporter credentials in the repository.

For a command-line upload handoff, prepare one approved authentication path on the upload machine:

- App Store Connect API key ID, issuer ID, and private key file for Transporter-based upload authentication.
- Or an Apple ID plus app-specific password for an altool fallback path where available.

Token Monitor only checks the presence of these inputs:

```bash
TOKEN_MONITOR_APP_STORE_CONNECT_API_KEY_ID="<key-id>" \
TOKEN_MONITOR_APP_STORE_CONNECT_API_ISSUER_ID="<issuer-id>" \
TOKEN_MONITOR_APP_STORE_CONNECT_API_PRIVATE_KEY_PATH="/secure/path/AuthKey_<key-id>.p8" \
./scripts/check-app-store-upload-readiness.sh
```

or:

```bash
TOKEN_MONITOR_APP_STORE_USERNAME="<apple-id>" \
TOKEN_MONITOR_APP_STORE_APP_PASSWORD="<app-specific-password>" \
./scripts/check-app-store-upload-readiness.sh
```

The readiness check does not upload anything.

## After Credentials Are Ready

Use this operator sequence after the Apple Developer certificate, notary credentials, and GitHub secrets exist:

```bash
TOKEN_MONITOR_APPLE_TEAM_ID="<TEAMID>" \
TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY=1 \
TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED=1 \
TOKEN_MONITOR_DIRECT_DMG_APPROVED=1 \
TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED=1 \
TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED=1 \
TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED=1 \
./scripts/check-apple-access-handoff.sh --require-direct-dmg-access

./scripts/check-github-release-variables.sh --require-direct-dmg-variables

./scripts/check-github-release-secrets.sh --require-signing-secrets

xcrun notarytool store-credentials token-monitor-notary

./scripts/preflight-release.sh --require-signing-secrets --require-apple-access-handoff

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh --require-distribution-ready

TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 \
./scripts/verify-public-release.sh <tag> <version> <build>

./scripts/audit-apple-distribution.sh --require-complete --run-tests
```

Run the consolidated audit again after publishing and after any App Store Connect handoff changes:

```bash
./scripts/audit-apple-distribution.sh --require-complete --run-tests
```

For a GitHub Actions rebuild of an existing release, run the `Release` workflow manually with the existing tag after the required repository secrets pass the strict check. Enable the `require_developer_id` workflow option so the job fails before upload if signing, notarization, or Gatekeeper/stapler verification is incomplete.

## Notarization Password

Create an app-specific password for the Apple ID used for notarization. Store it as:

```text
TOKEN_MONITOR_NOTARY_APP_PASSWORD
```

The workflow combines this with:

```text
TOKEN_MONITOR_NOTARY_APPLE_ID
TOKEN_MONITOR_NOTARY_TEAM_ID
```

and creates a temporary `notarytool` profile during the release job.

## Local Verification

After the certificate is installed locally, verify readiness:

```bash
./scripts/check-apple-distribution.sh
```

After local notary credentials are stored, verify again:

```bash
xcrun notarytool store-credentials token-monitor-notary

TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
./scripts/check-apple-distribution.sh
```

Use strict mode after a signed/notarized build exists:

```bash
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
./scripts/check-apple-distribution.sh --require-ready
```

## Release Verification

After publishing a GitHub Release, verify:

```bash
codesign --verify --deep --strict dist/TokenMonitor.app
spctl --assess --type execute --verbose=4 dist/TokenMonitor.app
xcrun stapler validate dist/TokenMonitor-macOS.dmg
```

The expected result for a public release is:

- App signature verifies.
- Gatekeeper accepts the app.
- DMG has a stapled notarization ticket.
- Sparkle appcast is published to GitHub Pages.

## Rotation

Rotate secrets if:

- The `.p12` file was exposed.
- The certificate password was shared outside the approved operator path.
- A GitHub Actions log shows unexpected signing output.
- Apple Developer team membership changes.

When rotating, replace the GitHub Secrets first, then publish a small test release and verify notarization before broader distribution.
