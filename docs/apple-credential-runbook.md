# Apple Credential Runbook

Last reviewed: 2026-05-02

This runbook explains how to prepare Token Monitor for Developer ID signing and notarization without putting Apple credentials into chat, source files, or release artifacts.

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
TOKEN_MONITOR_REQUIRE_SIGNING_SECRETS=1 ./scripts/check-github-release-secrets.sh
```

## After Credentials Are Ready

Use this operator sequence after the Apple Developer certificate, notary credentials, and GitHub secrets exist:

```bash
TOKEN_MONITOR_REQUIRE_SIGNING_SECRETS=1 ./scripts/check-github-release-secrets.sh

xcrun notarytool store-credentials token-monitor-notary

./scripts/preflight-release.sh --require-signing-secrets

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh

TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 \
./scripts/verify-public-release.sh <tag> <version> <build>
```

For a GitHub Actions rebuild of an existing release, run the `Release` workflow manually with the existing tag after the required repository secrets pass the strict check.

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
