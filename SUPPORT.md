# Token Monitor Support

Use GitHub Issues for public support and sanitized bug reports:

```text
https://github.com/MediaPublishing/token-monitor/issues
```

GitHub Issues are public. Do not post raw debug dumps, screenshots with private account data, chat titles, usage budgets, balances, email addresses, access tokens, or Apple credentials.

## Installation Or Gatekeeper

For installation and Gatekeeper questions:

1. Check the install instructions in `README.md`.
2. Include your macOS version.
3. Include the Token Monitor version and build.
4. Describe where the install flow stopped.
5. Redact screenshots before posting.

Preview builds can show Apple's warning until a Developer ID signed and notarized build is published.

## Claude, ChatGPT, Or Codex Parser Bugs

Use the parser/layout issue form:

```text
https://github.com/MediaPublishing/token-monitor/issues/new?template=parser-layout-bug.yml
```

Include sanitized visible metrics, reset labels, account language, Token Monitor version, and what the app shows. Percentages and reset labels are usually enough.

Do not attach raw debug dumps publicly.

## Privacy Or Sensitive Data

Read the privacy summary first:

```text
https://github.com/MediaPublishing/token-monitor/blob/main/docs/privacy.md
```

For sensitive concerns, use GitHub private vulnerability reporting if available for the repository. Do not open a public issue with private account data.

## Developer ID Or Release Problems

For release/signing/notarization work, use the repo runbooks:

- `docs/apple-distribution-readiness.md`
- `docs/apple-credential-runbook.md`
- `scripts/check-apple-distribution.sh`
- `scripts/verify-public-release.sh`

Never paste Apple ID passwords, certificate passwords, `.p12` contents, app-specific passwords, or GitHub Secrets into a public issue.
