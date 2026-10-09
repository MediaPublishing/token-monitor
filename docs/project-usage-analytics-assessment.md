# Optional Project Usage Analytics

Reviewed: 2026-10-09

Owner clarification, 2026-10-09: omit estimated value and monetary figures. Aggregate recorded token consumption by project or topic; a thread list is only an optional drill-down, not the primary experience.

**Decision: adapt the concept as a deferred, opt-in product candidate. Documentation only; no scanning, imports, cloud processing, settings switch, or runtime integration is enabled.**

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

The useful addition would be a separate optional analysis window. It should not widen the menu-bar meter, add project rows to the capacity dropdown, or interfere with authentication and refresh reliability. No cost/value calculation is part of the proposed feature.

## Thread Usage Feasibility

- [Codex token accounting](https://github.com/openai/symphony/blob/main/elixir/docs/token_accounting.md) describes thread-scoped cumulative usage notifications. Use the newest accepted cumulative snapshot for a thread, not the sum of repeated snapshots. Context-window values are not consumption.
- [Claude Code / Agent SDK usage tracking](https://code.claude.com/docs/en/agent-sdk/cost-tracking) exposes per-step and session usage. Deduplicate message IDs, respect resumed-session/reset semantics, and account for subagents through the appropriate whole-tree source. SDK availability does not prove that every installed version's historical transcript contains complete equivalent records.
- This supports the concept for coding sessions, not a claim that every native/web ChatGPT or Claude conversation exposes historical token totals. Verify each installed source format before implementation; unavailable data must not become zero or an inferred quota percentage.

## Proposed First Scope

- Settings entry **Project analytics**, off by default. Opening it before setup explains supported sources and requires explicit source selection; enabling it alone grants no cloud access.
- A separate **Projects & Usage** window, with a week/month selector and **Project / Topic** grouping. One row per group shows recorded tokens, share of covered usage, thread count, and data freshness. Provider/model breakdown and individual threads appear only on drill-down.
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

The existing [optional session overview](product-backlog.md#deferred-idea-optional-session-overview) remains separately deferred. This review does not resume its scanner or navigation work. Implement either feature only after an explicit implementation request; share source adapters later only if both approved scopes genuinely need them.
