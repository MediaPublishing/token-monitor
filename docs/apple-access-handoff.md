# Apple Access Handoff

Last reviewed: 2026-05-13

## Purpose

Use this checklist when Apple Developer access is created for Token Monitor.
It keeps the access narrow, avoids password sharing, and separates the direct Developer ID release path from a possible Mac App Store submission.

Do not paste Apple ID passwords, app-specific passwords, certificate passwords, API private keys, or `.p12` files into chat, issues, docs, or commits.

## Recommended Access Model

Preferred:

1. The Account Holder keeps ownership of the Apple Developer Program and App Store Connect account.
2. The Account Holder invites a release operator in App Store Connect instead of sharing the Account Holder login.
3. The operator gets the minimum role needed for the current task.
4. Certificate files and App Store Connect API keys stay outside the repository.
5. Final App Review submission remains an Account Holder-approved action.

## Role Matrix

| Task | Minimum practical access | Notes |
| --- | --- | --- |
| Inspect App Store Connect app setup | Developer or App Manager | App access can usually be limited to Token Monitor after the app record exists. |
| Edit metadata, screenshots, pricing, and release notes | App Manager | Needed for the Mac App Store track, not for direct DMG distribution. |
| Upload a MAS build | Developer or App Manager plus upload credentials | Upload still requires a signed package and an approved upload tool/authentication path. |
| Create Apple Distribution certificates | Account Holder or Admin | Needed for Mac App Store signed builds. |
| Create Developer ID certificates | Account Holder, or Admin only when Apple grants the required cloud-managed Developer ID certificate access | Needed to remove Gatekeeper warnings for direct DMG distribution. |
| Sign legal agreements, paid apps agreement, tax, and banking | Account Holder | Do not delegate this through shared credentials. |
| Create or approve App Store Connect API keys | Account Holder/Admin/App Manager/Developer depending on team policy and API role | Use the smallest API role that supports the upload or metadata operation. |
| Final App Review submission | Account Holder or explicitly approved App Manager | Keep this as a deliberate approval gate. |

## Invitation Checklist

Before inviting anyone:

- Confirm whether the team is an organization or individual Apple Developer Program account.
- Confirm whether direct DMG distribution, Mac App Store submission, or both are being pursued.
- Confirm the Apple Team ID and the intended bundle ID owner.
- Confirm the App Store Connect SKU and category against `docs/app-store-connect-identity.md`.
- Confirm whether the operator should touch certificates or only metadata/upload handoff.

If only direct Developer ID DMG distribution is needed:

- Confirm the non-secret access handoff:

```bash
TOKEN_MONITOR_APPLE_TEAM_ID="<TEAMID>" \
TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY=1 \
TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED=1 \
TOKEN_MONITOR_DIRECT_DMG_APPROVED=1 \
TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED=1 \
TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED=1 \
TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED=1 \
./scripts/check-apple-access-handoff.sh --require-direct-dmg-access
```

- Account Holder creates or approves the Developer ID Application certificate.
- Account Holder or approved operator exports the `.p12` on the release Mac.
- Add the GitHub secrets listed in `docs/apple-credential-runbook.md`.
- Run `./scripts/check-github-release-secrets.sh --require-signing-secrets`.
- Run `./scripts/preflight-release.sh --require-signing-secrets`.

If Mac App Store submission is pursued:

- Confirm the Mac App Store access handoff:

```bash
TOKEN_MONITOR_APPLE_TEAM_ID="<TEAMID>" \
TOKEN_MONITOR_MAS_TRACK_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_CONNECT_READY=1 \
TOKEN_MONITOR_APP_STORE_CERTIFICATES_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_UPLOAD_AUTH_APPROVED=1 \
TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED=1 \
./scripts/check-apple-access-handoff.sh --require-mas-access
```

- Create the App Store Connect app record.
- Assign app-specific access for Token Monitor where possible.
- Prepare Apple Distribution and Mac App Store installer distribution certificates.
- Prepare upload authentication on the upload machine.
- Run `./scripts/check-app-store-identity.sh --require-ready` if the App Store Connect record is being created before the full preflight.
- Run `./scripts/preflight-mas-submission.sh`, which includes the strict App Store Connect identity gate.
- Run `./scripts/check-app-store-upload-readiness.sh --require-ready`.
- Run `./scripts/check-app-store-submission-gates.sh --require-human-gates`.

## Information To Share With The Operator

Safe to share:

- Apple Team ID.
- Exact certificate identity names after they exist.
- App Store Connect app record URL.
- Bundle ID.
- Repository URL.
- Which path is approved: direct Developer ID DMG, Mac App Store, or both.

Do not share in chat:

- Apple ID password.
- App-specific password.
- `.p12` file or certificate password.
- App Store Connect API private key.
- GitHub secret values.
- Provider reviewer account passwords unless a secure password manager handoff is approved.

## Revocation Checklist

After release work is done or if access is no longer needed:

1. Remove or downgrade unnecessary App Store Connect roles.
2. Revoke or rotate API keys that were only created for the release.
3. Rotate GitHub secrets if any secret value was exposed outside the approved path.
4. Re-run `./scripts/check-github-release-secrets.sh`.
5. Keep the final signed artifacts and verification output, not the raw private keys.

## Source References

- Apple App Store Connect role permissions: https://developer.apple.com/help/app-store-connect/reference/role-permissions
- Apple add and edit users: https://developer.apple.com/help/app-store-connect/manage-your-team/add-and-edit-users/
- Apple Developer ID certificates: https://developer.apple.com/help/account/create-certificates/create-developer-id-certificates/
- Apple certificates overview: https://developer.apple.com/help/account/certificates/certificates-overview/
