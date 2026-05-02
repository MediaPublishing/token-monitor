# Token Monitor Privacy

Last reviewed: 2026-05-02

Token Monitor is designed as a local macOS utility. It does not require a Token Monitor account and does not send usage data to Token Monitor server infrastructure.

This document is a product privacy summary. It should be reviewed before being used as a formal App Store privacy policy.

## What The App Does

Token Monitor displays Claude, ChatGPT, and Codex usage status in a macOS menu bar app. To do that, it opens provider pages in embedded WebKit sessions after you sign in with those providers.

## Data Stored Locally

Token Monitor can store data on your Mac, including:

- Provider login sessions managed by WebKit.
- Last known usage snapshots.
- App settings such as refresh behavior, launch-at-login preference, and debug mode.
- Opt-in diagnostic files when debug mode is enabled.

## Data Sent To Token Monitor

Token Monitor does not send your usage data, account data, login sessions, diagnostics, or screenshots to Token Monitor server infrastructure.

## Third-Party Providers

When you sign in to Claude, ChatGPT, or Codex through Token Monitor, those pages are provided by their respective services. Their own privacy policies and account terms apply to those sessions.

Token Monitor is not affiliated with Anthropic, OpenAI, or Apple.

## Debug Reports

Debug mode is off by default.

When debug mode is enabled, Token Monitor can prepare report drafts for GitHub Issues or email. Drafts are opened for your review first. Do not share raw debug dumps publicly if they contain private account data, chat titles, budgets, balances, email addresses, or access tokens.

## Public Issues

GitHub Issues are public. Parser/layout issues should use the structured issue form and include only sanitized details needed to reproduce the problem.

## Removing Local Data

To remove local Token Monitor data, quit Token Monitor and remove its app data from your macOS user Library. The exact storage paths can change between builds, so check the current app settings and Application Support folders before deleting anything.

## Contact

Use the public GitHub repository for support and sanitized bug reports:

```text
https://github.com/MediaPublishing/token-monitor/issues
```
