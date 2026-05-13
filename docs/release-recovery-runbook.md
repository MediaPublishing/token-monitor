# Release Recovery Runbook

Last reviewed: 2026-05-13

## Purpose

Use this when a public Token Monitor release, DMG, Sparkle update ZIP, appcast, or Mac App Store submission path is wrong after publication.

This runbook is operational guidance only. It does not approve a release, upload, App Store submission, credential rotation, or public support statement.

## First Response

1. Pause further release work.
2. Preserve evidence before changing anything:
   - GitHub Release URL and tag.
   - GitHub Actions run URL.
   - `appcast.xml` URL.
   - DMG and ZIP asset names.
   - User-facing error text or screenshot, with private data redacted.
3. Confirm whether the problem affects:
   - Direct DMG install.
   - Sparkle update.
   - GitHub release ZIP.
   - Mac App Store build or upload package.
   - Parser behavior after install.
4. Do not delete tags, force-push release branches, delete GitHub Pages, or rotate credentials until the failure mode is clear.

## Hotfix Release

Use this when the fix requires a code, parser, packaging, signing, or notarization change.

1. Fix the issue on `main`.
2. Run local verification:

```bash
swift test
./scripts/audit-apple-distribution.sh --skip-network
```

3. Build and verify with the strict release path after Developer ID credentials exist:

```bash
./scripts/preflight-release.sh --require-signing-secrets --require-distribution-ready

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh --require-distribution-ready
```

4. Publish a new GitHub Release with a higher version/build.
5. Verify public assets:

```bash
TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 \
./scripts/verify-public-release.sh <tag> <version> <build>
```

6. Post a sanitized support note only after verification is complete.

## Appcast Rollback

Use this only when the current Sparkle appcast points users to a bad update and a hotfix cannot be published quickly.

Preferred rollback path:

1. Identify the last known-good tag, version, and build.
2. Manually dispatch the `Release` workflow with the last known-good tag.
3. Enable `require_developer_id` when Developer ID credentials are configured.
4. Wait for the workflow to redeploy GitHub Pages.
5. Verify the public appcast and assets:

```bash
TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 \
./scripts/verify-public-release.sh <known-good-tag> <known-good-version> <known-good-build>
```

6. Record the rollback reason in the GitHub Release notes or a linked issue.

This repoints the public Sparkle appcast to the known-good update ZIP. It does not remove the newer GitHub Release from history.

## Mac App Store Recovery

If a Mac App Store build or upload package is wrong:

1. Do not upload a replacement package until the Account Holder approves the recovery path.
2. Re-run the technical preflight:

```bash
./scripts/preflight-mas-submission.sh
```

3. Re-run the human gates:

```bash
./scripts/check-app-store-submission-gates.sh --require-human-gates
```

4. Re-run upload handoff:

```bash
./scripts/check-app-store-upload-readiness.sh --require-ready
```

5. If the issue involves App Review metadata, privacy labels, screenshots, reviewer notes, or test accounts, update App Store Connect only after Account Holder approval.

## Credential Exposure

If any secret might have been exposed:

- Apple credentials: revoke or rotate the affected app-specific password, API key, or certificate according to `docs/apple-access-handoff.md` and `docs/apple-credential-runbook.md`.
- `SPARKLE_PRIVATE_KEY`: rotate the Sparkle signing key, update the app's public key in a new signed build, and do not publish new appcasts with the exposed key.
- GitHub Secrets: rotate the relevant secret and re-run `./scripts/check-github-release-secrets.sh`.
- Provider reviewer account passwords: rotate through the approved password manager path.

Do not post secrets, `.p12` files, API private keys, passwords, raw debug dumps, or unredacted screenshots in GitHub Issues.

## Support And Issue Triage

GitHub Issues are public. Public replies must be sanitized.

Allowed in public:

- App version and build.
- macOS version.
- Sanitized error text.
- Sanitized screenshots without account data.
- Reproduction steps.

Not allowed in public:

- Apple credentials.
- GitHub Secrets.
- Provider account data.
- Raw debug dumps.
- Chat titles, balances, budgets, cookies, tokens, or email addresses.

## Do Not

- Do not delete release tags as the first recovery action.
- Do not force-push history to hide a bad release.
- Do not upload a signed but non-notarized Developer ID release.
- Do not republish App Store metadata or privacy claims without approval.
- Do not tell users to bypass Gatekeeper for a build that is expected to be signed and notarized.
- Do not attach private debug data to public GitHub Issues.
