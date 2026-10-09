# Optional Project Usage Analytics

Reviewed: 2026-10-09

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

The useful addition would be a separate optional analysis window. It should not widen the menu-bar meter, add project rows to the capacity dropdown, or interfere with authentication and refresh reliability.

## Proposed First Scope

- Settings entry **Project analytics**, off by default. Opening it before setup explains supported sources and requires explicit source selection; enabling it alone grants no cloud access.
- A separate **Projects & Usage** window, with a week/month selector and rows for project, source/provider, recorded usage, and data freshness. Show tokens only where a source supplies them; never invent token counts from capacity percentages.
- Start with read-only local metadata for Codex and Claude Code, subject to a format/support feasibility check. Native ChatGPT, Claude Desktop, Cowork, Cursor, and OpenCode are not implicitly covered by those importers.
- Attribute work through reliable project/repository metadata and editable local mappings. Keep an **Unassigned** bucket instead of guessing an account or business line.
- Show source coverage, unavailable sources, and missing values explicitly. A partial local view must not claim to represent all AI usage.
- No conversation bodies, semantic classification, browser invoice extraction, cloud agent API connectors, or automatic ROI claims in the first scope.

Suggested layout:

```text
Projects & Usage                            This week
Project          Provider     Recorded usage   Updated
Project A        Claude Code  source value     timestamp
Project B        Codex        source value     timestamp
Unassigned       mixed        source value     timestamp

Sources: selected local sources; coverage incomplete
Costs: unavailable until a supported accounting source exists
```

This is a proposed specification, not a shipped screen or a promise of source compatibility.

## Accounting And Privacy Rules

1. Separate **actual invoiced/API cost**, **allocated subscription cost**, and **API price equivalent**. Each needs its source, currency, period, and method. A price equivalent is neither a bill nor money saved.
2. Subscription allocation is optional and explicitly estimated. Allocations must reconcile with the entered bill, including unassigned usage; incomplete local coverage must remain visible.
3. Preserve input, output, and cached-token distinctions when available. Unknown model/rate combinations remain unpriced, not zero; rate tables need effective dates and provenance.
4. Session elapsed time is not employee work time, agent runtime, or productivity. Omit it initially unless a defensible activity measure is available; do not sum overlapping sessions as human hours.
5. Import incrementally with stable event identities, deduplication, and bounded retention. Unsupported source changes must leave capacity monitoring unaffected. Give users local exclusion and deletion controls.
6. Store only necessary normalized usage/project metadata. Do not read or retain prompts, answers, secrets, or customer content for classification. Reading mixed-content log files still needs an explicit source consent and a bounded parser.
7. Keep project names, paths, identifiers, and usage records out of public debug reports and automatic uploads. Exports require a user-selected destination and review.
8. Any later embeddings, Jev/Gemini processing, cloud records, or invoice ingestion needs a separate scope and explicit data-recipient/access approval. Local activation must never imply external processing consent.
9. Business impact needs independently sourced outcomes or user-entered goals. Token volume, PR counts, and allocated cost alone cannot prove ROI.

## Before Implementation

- Confirm supported local formats and obtain synthetic fixtures; do not inspect private conversation archives as part of this concept review.
- Specify the importer boundary, retention and exclusion controls, project mapping, coverage indicators, and accounting labels before building UI.
- Test duplicate imports, missing/corrupt records, rotated logs, overlapping sessions, multi-account ambiguity, unpriced models, and unavailable sources.
- Verify that disabling analytics stops all analytics reads and that failures never affect quota refresh, account sessions, or the menu bar.

The existing [optional session overview](product-backlog.md#deferred-idea-optional-session-overview) remains separately deferred. This review does not resume its scanner or navigation work. Implement either feature only after an explicit implementation request; share source adapters later only if both approved scopes genuinely need them.
