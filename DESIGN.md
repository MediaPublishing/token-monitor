# Token Monitor Landing Page Design

## Goal

Turn the existing technical preview page into a focused product landing page for macOS AI power users. The page should help a visitor understand the utility, trust the local-first model, inspect the real interface, and download the current preview build without reading repository documentation first.

## Audience

- People who use Claude, ChatGPT/Codex, or OpenCode Go throughout the workday.
- macOS users who want quota and reset windows visible before starting a long AI task.
- Technical users who value local sessions and inspectable source code, without making the page feel developer-only.

## Design direction

- Dark macOS utility aesthetic with violet as the primary action color and green as the healthy-state color.
- Real product screenshots are the main visual proof. No fake dashboard mockups or generic AI imagery.
- One prominent download action, one quieter product-preview action, and GitHub as a secondary trust path.
- English and German remain equally supported. The browser language chooses the initial version and the visitor can switch manually.
- Compact sections, generous spacing, readable line lengths, and no nested card grids.

## Information hierarchy

1. Product promise, supported providers, and download.
2. Real interface and the problem it removes.
3. Provider-specific views and local-first privacy model.
4. Three-step installation with an honest preview/Gatekeeper note.
5. FAQ, source code, privacy, and final download.

## Acceptance criteria

- The first viewport says who the app is for, what it does, and what to do next.
- The dashboard is legible and visually dominant on desktop and mobile.
- Every public claim is supported by the repository documentation.
- The current `v1.0.34` DMG and release links resolve.
- Layout works at 1440 px desktop and 390 px mobile without overflow.
- Keyboard focus, reduced motion, semantic headings, alt text, and language switching work.

## Non-goals

- No Cloudflare Pages or GitHub Pages deployment without explicit publishing approval.
- No claims that the current preview is Developer ID signed, notarized, or Mac App Store approved.
- No analytics, tracking, newsletter form, pricing, or hosted account flow.
