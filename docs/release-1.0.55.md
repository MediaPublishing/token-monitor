# Token Monitor 1.0.55

<!-- token-monitor:prebuilt-notarized -->

## Claude Session-Only Limits

- Fix a reproduced layout error for Claude accounts that expose a session
  quota but no weekly quota. Read the actual session values without requiring
  or inventing a weekly limit.
- Preserve missing limits in the dashboard and every menu-bar layout.
- Recognize weekly-limit headings exactly, rather than treating explanatory
  text such as usage-by-product as a quota.
- Continue retrying when a visible weekly section is incomplete; never borrow
  a percentage from another usage card.
- Safely include optional model limits when only one core quota exists.
- Keep private, opt-in diagnostics, account isolation and existing sign-ins.

This fixes the parser defect reproduced from the reported structural pattern.
The affected user's live account still needs a confirmation test. It does not
claim to explain or resolve every historical provider-page failure.

## Claude ohne Wochenlimit

Claude-Konten mit einem Sitzungslimit, aber ohne Wochenlimit werden nicht mehr
allein wegen des fehlenden Wochenlimits als Layoutfehler abgewiesen. Dashboard
und Menüleiste zeigen nur tatsächlich vorhandene Limits. Erklärungstexte zur
Nutzung dieser Woche zählen nicht als Wochenlimit. Unvollständig geladene
Wochenabschnitte werden weiterhin erneut geprüft.

Die datensparsame Diagnose bleibt erhalten. Konten und bestehende Anmeldungen
werden nicht zurückgesetzt. Der Fehler ist mit Testdaten reproduziert und
korrigiert; die Bestätigung am betroffenen Konto steht noch aus.
