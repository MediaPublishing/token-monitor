# Security Policy

## Supported Versions

Security fixes are handled for the latest public Token Monitor release.

Before reporting, check the latest release:

```text
https://github.com/MediaPublishing/token-monitor/releases/latest
```

## Reporting A Vulnerability

Do not open a public issue for vulnerabilities, leaked credentials, private debug dumps, access tokens, `.p12` files, Apple credentials, GitHub Secrets, or account/session data.

Use GitHub private vulnerability reporting if it is available for this repository:

```text
https://github.com/MediaPublishing/token-monitor/security
```

If private vulnerability reporting is unavailable, open a minimal public issue that says a private security report is needed, without including sensitive details.

## Not Security Issues

These should usually use normal support or parser issue routes instead:

- Claude, ChatGPT, or Codex layout/parser failures without credential exposure.
- Gatekeeper warnings from unsigned preview builds.
- General installation questions.
- Feature requests.

## Sensitive Data

Never post these publicly:

- Raw debug dumps.
- Screenshots with private account data.
- Chat titles.
- Usage budgets or balances.
- Email addresses.
- Access tokens or cookies.
- Apple ID passwords.
- App-specific passwords.
- Developer ID `.p12` files or passwords.
- GitHub Secrets.

## Local Data Model

Token Monitor is designed as a local macOS app. It uses local WebKit sessions, local settings, local snapshots, and opt-in debug drafts. See `docs/privacy.md` for the product privacy summary.
