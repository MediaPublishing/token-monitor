# Optional Project Usage Analytics

Reviewed: 2026-10-09

Owner clarification, 2026-10-09: omit estimated value and monetary figures. Aggregate recorded token consumption by project or topic; a thread list is only an optional drill-down, not the primary experience.

**Decision updated 2026-10-10: implementation approved for an optional local tab. Variant 1 plus variant 3 disclosures and the topic switch; no chart or monetary values. The separate active-session navigation idea is still deferred.**

## Implementation Contract

- AC-1: analysis is off by default; enabling it exposes a quiet Capacity / Analysis tab switch. No log reads while disabled. Source switches separately control Codex and Claude Code.
- AC-2: Projects / Topics grouping, last 7 / 30 days, recorded token totals and shares, with provider disclosures. No financial values or trend chart.
- AC-3: project/topic assignments are editable locally and survive app restarts. Unknown project/topic values stay unassigned. Thread lists remain secondary.
- AC-4: normalized local token records only; no conversation text, credentials, external processing, network request, or analytics additions to debug reports. Scan bounded regular JSONL files only; skip symlinks.
- AC-5: repeated counters/messages, cache/reasoning subsets, source overlap, parent/subagent rollups, fork history, malformed lines, missing data, period boundaries, and disabled/cancelled refreshes have focused tests or explicit conservative coverage limits.
- AC-6: native screenshots and interaction checks in light/dark and collapsed/expanded states; refreshing does not change the fixed control footprint. Existing capacity tests still pass.
- AC-7: build and locally install with the same bundle identifier, after backing up the old app. Preserve all provider session/account stores. Verify installed identity and launch.
- Non-goals: public release/download-page deployment, invoice/API valuation, automatic topic inference, session navigation/control, and Apple distribution changes.
- Gates: focused tests plus existing suite/build, source review, live UI proof and independent read-only final check. At most three correction cycles. Private live usage records/screenshots are not public artifacts.

## Source And Evidence

Reference: [Claire Vo's project-usage analysis thread](https://x.com/clairevo/status/2108364438642507817), published 2026-10-09 UTC. The post, author continuations, and dashboard image were reviewed directly. This is a reported personal workflow, not a verified benchmark or an available app implementation.

- [Data sources](https://x.com/clairevo/status/2108364440529928328): local Codex and Claude Code logs, Cursor's local database, cloud agent records, GitHub PR metadata, and invoices.
- [Matching](https://x.com/clairevo/status/2108364441645715890) and [grouping](https://x.com/clairevo/status/2108364443151442347): embeddings, Jev relationship judgments, graph clusters, and Gemini-generated theme names.
- [Measures](https://x.com/clairevo/status/2108364445840011653): token counts, estimated and actual costs, and session hours grouped by business line, week, tool, or model.
- [Important clarification](https://x.com/clairevo/status/2108371611217023337): estimated value means API list-price equivalent, not business value; linking business outcomes was still a next step. The dashboard likewise labels its estimate as retail-equivalent and not billed, with a local-log session-time heuristic.

The author's $0.12 analysis-cost claim does not establish collection, setup, storage, inference, or maintenance costs for a shipping feature. No upstream software, code, credentials, or dependencies were imported.

## Fit With Token Monitor

Token Monitor answers **how much subscription capacity remains until reset**. Project analytics answers **which work consumed recorded usage**. They should not share an ambiguous percentage or monetary total.

The current `ServiceSnapshot` and `FileSnapshotStore` hold latest provider capacity readings, not per-project token events or a historical usage ledger. Differences between quota readings cannot reconstruct project spend: resets, rolling windows, concurrent accounts, and provider-specific accounting invalidate that inference.

The approved addition is a separate optional analysis tab. It does not widen the menu-bar meter, add project rows to the capacity view, or interfere with authentication and refresh reliability. No cost/value calculation is part of this feature.

## Thread Usage Feasibility

- [Codex token accounting](https://github.com/openai/symphony/blob/main/elixir/docs/token_accounting.md) describes thread-scoped cumulative usage notifications. Use the newest accepted cumulative snapshot for a thread, not the sum of repeated snapshots. Context-window values are not consumption.
- [Claude Code / Agent SDK usage tracking](https://code.claude.com/docs/en/agent-sdk/cost-tracking) exposes per-step and session usage. Deduplicate message IDs, respect resumed-session/reset semantics, and account for subagents through the appropriate whole-tree source. SDK availability does not prove that every installed version's historical transcript contains complete equivalent records.
- This supports the concept for coding sessions, not a claim that every native/web ChatGPT or Claude conversation exposes historical token totals. Verify each installed source format before implementation; unavailable data must not become zero or an inferred quota percentage.

## Proposed First Scope

- Settings entry **Project analytics**, off by default. Opening it before setup explains supported sources and requires explicit source selection; enabling it alone grants no cloud access.
- A separate **Analysis** tab, with a 7/30-day selector and **Projects / Topics** grouping. One row per group shows recorded tokens, share of covered usage, thread count, and data freshness. Provider breakdown and individual thread identifiers appear only on drill-down.
- Start with read-only local metadata for Codex and Claude Code, subject to a format/support feasibility check. Native ChatGPT, Claude Desktop, Cowork, Cursor, and OpenCode are not implicitly covered by those importers.
- Map reliable project/repository metadata to editable project groups across apps. Assign topics manually or through explicit metadata rules initially; no automatic semantic classification of conversation bodies. Keep an **Unassigned** bucket instead of guessing an account or business line.
- A usage event has one primary project and one primary topic so each grouping reconciles to the same total. Optional overlapping tags are filters, not additive buckets. A mixed-topic thread can be assigned as a whole; splitting it requires supported event-level mapping, not invented precision.
- Show source coverage, unavailable sources, and missing values explicitly. A partial local view must not claim to represent all AI usage.
- No conversation bodies, semantic classification, browser invoice extraction, cloud agent API connectors, or automatic ROI claims in the first scope.

Suggested layout:

```text
Projects & Usage                            This week
Group by: Project | Topic
Project          Recorded tokens   Share       Threads
Project A        source total      calculated  count
Project B        source total      calculated  count
Unassigned       source total      calculated  count

Sources: selected local sources; coverage incomplete
Expand a group for provider breakdown and its threads
```

This is a proposed specification, not a shipped screen or a promise of source compatibility.

## Counting And Privacy Rules

1. Preserve input, output, and cache breakdowns using each source's semantics. Cached input may already be included in input, and reasoning may be included in output: never add subsets twice. Repeatedly processed context counts as recorded token activity, not unique written text.
2. Normalize source-reported usage, not model-context estimates. Handle cumulative snapshots, counter resets, duplicated imports, inherited fork totals, and parent/subagent rollups without double counting. Missing data remains unknown.
3. Use timestamped usage increments for week/month views, with an explicit timezone. A lifetime total alone cannot be assigned to the last active week. Report only supported periods, mark incomplete coverage, and reconcile project/topic totals including unassigned usage.
4. Label proportions **Share of recorded usage**, not share of an account's subscription limit. Tokens across models can be aggregated as activity, but do not consume subscription capacity uniformly. Show the provider/model breakdown for interpretation.
5. Import incrementally with stable identities and bounded retention. Unsupported sources must leave capacity refresh unaffected. Give users local exclusion and deletion controls. Session-time and productivity estimates are outside the first scope.
6. Store only necessary normalized usage/group metadata. Do not read or retain conversation bodies, secrets, or customer content for classification. Reading mixed-content log files still needs explicit source consent and a bounded parser.
7. Keep group names, paths, identifiers, and usage records out of public debug reports and automatic uploads. Exports require a user-selected destination and review.
8. Any later semantic classification, embeddings, cloud records, or financial analysis needs a separate scope and explicit data-recipient/access approval. Local activation must never imply external processing consent.

## Before Implementation

- Confirm supported local formats and obtain synthetic fixtures; do not inspect private conversation archives as part of this concept review.
- Specify the importer boundary, retention and exclusion controls, project/topic mappings, token semantics, and coverage indicators before building UI.
- Test duplicate imports, missing/corrupt records, rotated logs, inherited fork totals, parent/subagent rollups, counter resets, period boundaries, multi-account ambiguity, overlapping topic tags, and unavailable sources.
- Verify that disabling analytics stops all analytics reads and that failures never affect quota refresh, account sessions, or the menu bar.

The existing [optional session overview](product-backlog.md#deferred-idea-optional-session-overview) remains separately deferred. Project analytics does not resume session navigation or live status work.

## Local Preview Operation

Enable **Settings > Project usage (optional) > Show analysis tab**. Codex and Claude Code can be selected separately. The analysis reads local token counters, not browser quotas; native/web chats and OpenCode are not covered by these source formats. No additional login is needed.

The 7/30-day totals include uncached input, cached input and output exactly once. Codex reasoning output is already included in output. Claude cache creation and cache reads are distinct input categories. Duplicated server messages and repeated cumulative counters are deduplicated; ambiguous baselines or resets are omitted and coverage stays explicitly incomplete. Percentages refer to the displayed recorded total, not remaining subscription capacity.

Expand a project for provider details, optional thread identifiers, and **Assignment**. Project aliases and one manual topic per project are saved locally in `~/Library/Application Support/TokenMonitor/Analytics/assignments.json` with restricted permissions. Token records are not persisted or added to debug reports. Disabling the feature cancels scanning and clears in-memory results without changing account sessions or deleting assignments.

Scanner limits: at most 1,500 files and 512 MiB per scan, split fairly across selected sources; 64 MiB per file and 2 MiB per line. Symbolic links and non-regular files are skipped. Events are filtered by their timestamps, not filesystem modification dates. Active logs bypass the parse cache. Old or unsupported formats can leave gaps; this is not a complete billing ledger.

Local preview version: **1.0.43 (48)**. Public downloads and landing pages remain **1.0.42**. Analytics does not modify provider sign-in or session storage. Build the synthetic test harness with `bash scripts/build-analytics-qa.sh` after `swift build`; it uses isolated logs and assignment/preferences stores and does not start account refreshes. The QA bundle lives under the hidden `.build/analytics-qa/` directory, not among normal app output. `TOKEN_MONITOR_QA_SDK` can select a compiler-compatible SDK.

Analytics UI verification, 2026-10-11 (build 45): the installed build passed the release build, signature and version checks, and all 112 tests in 12 suites. Native screenshot verification of the actual installed app is now complete: capacity/analysis switching, project/topic grouping, expanded provider details, 7/30-day selection and refresh were checked with local data. The picker titles no longer wrap into visible labels; their accessibility names remain intact. Longer project lists scroll inside the analysis area while the header and coverage footer stay fixed. Screenshots and private usage data remain local and are not published with the source. This verifies the local preview, not a new public release.
