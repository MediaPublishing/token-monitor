# Headroom Concept Review

Reviewed: 2026-10-09. Scope: concepts for Token Monitor, not installation or source import.

## Sources And Intake

- [Headroom website](https://headroom.zantos.co/), [release notes](https://headroom.zantos.co/release-notes), and [privacy policy](https://headroom.zantos.co/privacy), read directly over HTTPS.
- [Headroom 1.5 (41)](https://github.com/kylezantos/headroom-downloads/releases/tag/headroom-1.5-41), dated 2026-10-06.
- Download repository at `60074a5be597a210ec19fc906e4c2ca85cb261a5`: only a README. It explicitly states that app source is maintained separately. No public app source or source reuse license was found there.
- Vendor descriptions are claims, not independent runtime verification. No installer was downloaded or executed. No credentials, browser sessions, or upstream code were imported.
- Decision: **adapt concepts**, **keep existing owners**, no external runtime capability added. Manual review only, no upstream auto-update or integration.

## Decisions

| Idea | Decision | Token Monitor fit |
| --- | --- | --- |
| Distinguish loading from fresh readings without changing popover geometry | Adapt now | Refresh spinner belongs inside the existing fixed-size provider button. Keep last readings and their provenance visible; no additional loading row. |
| Individually choose and reorder menu-bar providers/limits, including closest to limit | Document as next improvement | Extend the existing menu-bar settings rather than a second dashboard. A per-provider override could select Session, Total, a model limit, or the lowest remaining percentage. Always name the selected window in the tooltip. Do not equate a 5-hour limit with a weekly limit or replace the current single-bar Both mode. |
| Notify when a new Codex banked reset arrives | Document as optional extension | Reuse the existing reset inventory and reminder controller. Require a confirmed fresh inventory increase, deduplicate by inventory transition, and keep opt-in. Current expiry reminders remain unchanged. |
| Reminder before a regular quota reset when capacity remains | Defer | Can easily produce noise or encourage unnecessary usage. Distinguish regular quota reset from expiring banked resets; expiry reminders are already more useful. |
| Per-account refresh schedules and immediate individual results | Keep | Current refresh tasks already run per account and update each result independently. Changing schedules needs evidence of polling or reliability problems, not just feature parity. |
| Live settings previews and neutral colors until low capacity | Defer | Potentially useful when the settings surface grows; not necessary for the current refresh correction. Preserve the established compact interface. |
| CLI/local sign-in based usage retrieval | Separate feasibility work only | Could reduce WebKit login fragility, but the vendor description does not establish supported endpoints, scopes, credential handling, or compatibility. Do not read/import external credentials or swap the current connection mechanism on this basis. |
| Mac widgets, iCloud/iPhone sync, API spend | Do not add in this task | New surfaces, data flows, and a different product scope. Local capacity monitoring remains the primary experience. |

## Small Readability Correction

Long provider reset hints already stay on one line to preserve dashboard geometry. Their full display text is now available on hover; this avoids adding height solely for a long localized reset description. Popover size updates are also queued on the main run loop so they read committed account/detail settings, not the previous value emitted during `@Published`'s will-set notification.

The previously deferred active-session overview remains deferred. Headroom research does not resume it.
