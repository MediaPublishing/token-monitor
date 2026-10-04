# ChatGPT unified usage dashboard fix, 2026-10-04

## Reproduction and cause

Installed v1.0.38 (build 39) produced `parseFailure` at 2026-10-04T05:27:44Z after the existing authenticated WebKit session redirected from the legacy Codex usage route to the unified ChatGPT Usage dashboard. The new dashboard uses `Weekly limit`, a relative `Resets in ...` line, `% left`, and an inline numeric `credits remaining` balance. The old parser did not recognize the latter two formats and retained the previous successful snapshot. This was a failed refresh, not an exhausted budget.

Official source checked: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan . OpenAI documents shared allowances across eligible Codex, Work, Workspace Agents and ChatGPT for Excel surfaces, plan-dependent limits, and checking the displayed allowance, credit balance and reset time. This change reads the dashboard's actual values; it does not infer plan allowances or token counts.

## Change and verification

- Support `left` as remaining capacity and inline credit balance; preserve older English, German and model-specific layouts.
- Bound metric values and reset subtitles to the current card. Shared predicates cover both supported German credit headings. Loading/missing budgets remain unreadable, distinct from a real zero.
- Before fix: new regressions produced seven issues. Final: 94 tests in 10 suites passed. Tests cover 0/100 boundaries, shared/model-specific limit labels, relative reset text, missing/loading/failed payloads and adjacent cards.
- Direct release build and code signature verification passed. MAS build, verification and static readiness passed. Version consistency, public repository hygiene, shell syntax and diff whitespace checks passed.
- Advisory Apple distribution audit completed. Its one command failure was the expected dirty worktree check; existing Developer ID/notarization and App Store account/setup warnings remain. The established channel is the ad-hoc public prerelease, not a new App Store release.
- Independent read-only checker: pass after two German card-boundary findings were fixed and regression-tested. Independent live data comparison: works.
- Final 1.0.39 build 40 ran alone with the existing WebKit session. Debug result at 2026-10-04T05:38:21Z was `success`; fresh snapshot contains weekly limit and credits. No secrets, cookies or auth state were copied.
- Non-sensitive test/build logs: `dist/pre-release-validation/1.0.39/qa/` (ignored local output).

## Remaining release gate

Version 1.0.39 build 40 is prepared locally. No new release/tag or public assets have been published. Visually checking the final app is blocked: root computer-use transport is closed; an independent app selection timed out. A later UI launch also started the installed old app in parallel; both diagnostic instances were stopped and the final live test above ran with only the new build. The original installed app remains unchanged, temporary debug mode is restored to false and the installed app is restarted on closeout.

Next: restore native UI access, visually check Token Monitor with the final build, push the verified main commit, confirm CI including isolated startup smoke test, create the explicitly authorized v1.0.39 GitHub prerelease through the existing Release workflow, deploy the existing Cloudflare Pages project, run `scripts/verify-public-release.sh v1.0.39 1.0.39 40`, verify downloaded app version/signature and the Sparkle update ZIP, and only then report successful publication. Do not modify or close Reto's Comet/LinkedIn or OpenAI submission/help tabs.
