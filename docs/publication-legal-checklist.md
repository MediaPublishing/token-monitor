# Publication Legal Checklist

Last reviewed: 2026-05-02

This checklist tracks publication decisions that require human or legal approval before broad public distribution, paid promotion, or App Store submission.

## Current Status

- No repository license is published yet.
- No formal App Store privacy policy has been legally approved yet.
- `docs/privacy.md` is a product privacy summary, not a legal policy.
- Public compatibility, privacy, notarization, and security claims require human review before paid or App Store distribution.

## Required Decisions

Before broad public promotion:

1. Decide whether the repository should remain source-visible without an open-source license, or publish a selected license.
2. Add the approved `LICENSE` file if a license is selected.
3. Confirm whether third-party names such as Claude, ChatGPT, Codex, Anthropic, OpenAI, and Apple are used only in nominative/descriptive ways.
4. Review the landing page, README, release notes, and launch copy for unsupported claims.
5. Approve the support and security reporting routes.

Before Mac App Store submission:

1. Approve the final privacy policy URL.
2. Complete App Store privacy labels.
3. Approve App Review notes.
4. Confirm screenshots contain no private account data.
5. Confirm support URL and marketing URL are final.
6. Account Holder approves submission.

## Do Not Do Without Approval

- Do not choose a software license on behalf of the owner.
- Do not add paid marketing claims about privacy, security, notarization, or compatibility without review.
- Do not submit App Store metadata without Account Holder approval.
- Do not publish user-provided debug data.
- Do not imply affiliation with Anthropic, OpenAI, Apple, Claude, ChatGPT, or Codex.

## Evidence Already Prepared

- Privacy summary: `docs/privacy.md`.
- Support routing: `SUPPORT.md`.
- Security reporting: `SECURITY.md`.
- Marketing metadata draft: `docs/marketing-launch-kit.md`.
- Mac App Store feasibility audit: `docs/mac-app-store-feasibility.md`.
