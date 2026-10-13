# App screenshots

Version: 1.0.44 (53). These are native SwiftUI/AppKit views captured with synthetic example data, not private account screenshots. Dashboard sections use the production `ServiceSectionView` with successful fixture refresh states; the Settings example shows restored, stale fixture accounts. Analysis totals come from generated local Codex/Claude Code fixtures. All provider logos use the app's genuine bundled vector assets.

Regenerate with the isolated QA app:

```bash
bash scripts/build-analytics-qa.sh
.build/analytics-qa/AnalyticsQA.app/Contents/MacOS/AnalyticsQA .build/marketing-home --proof .build/marketing-proof --marketing
```

The named `dashboard`, `claude`, `chatgpt`, `analysis` and `settings` PNGs are captured at a 2x bitmap size. No provider sign-in or network refresh is started. Native layout proofs are emitted separately. Landing-page captions explicitly label the examples.

`menu-bar-accounts.png` comes from `bash scripts/check-menu-bar-rendering.sh`, using the production `AppDelegate` with isolated synthetic cached accounts. The native-size and 2x detail views show 2/3/4/6 accounts; the verification also covers overflow through nine selected accounts and both 1x/2x bitmap representations. Orange/red reflect the fixture's cached/stale state, not any real account. No generated mockup is used as a production screenshot.
