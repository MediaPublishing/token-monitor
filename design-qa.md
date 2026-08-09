# Design QA

- Source dashboard: `/var/folders/_r/f3kmk9md1gzdm6yf9tfdwhym0000gn/T/codex-clipboard-8961145c-3f13-458c-9295-6a2d9fc43186.png`
- Source settings: `/var/folders/_r/f3kmk9md1gzdm6yf9tfdwhym0000gn/T/codex-clipboard-2fa13559-d86d-4bfa-b314-9bec3f12a075.png`
- Implementation dashboard: `output/token-monitor-dashboard-qa.png`

## Comparison

- The dashboard keeps the established three-provider layout and all connected providers remain healthy after the in-place update.
- Menu bar rows use the selected Session, Total, or Both meaning across ChatGPT, Claude, and OpenCode Go. In Both mode, both fills share one track and their endpoints remain marked.
- Settings cards use three explicit two-column rows with matching heights, and controls use a shared trailing alignment.
- The dashboard grows from 540 to 650 points when usage details are enabled, preventing the OpenCode Go section from being clipped.
- The settings popover height was increased to 700 points so the fixed rows do not clip their content.
- The new Session / Total / Both segmented selector is contained in the Status menu card and uses the same label-control alignment as the switches.

Final result: passed
