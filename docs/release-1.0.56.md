# Token Monitor 1.0.56

<!-- token-monitor:prebuilt-notarized -->

## More Resilient Claude Refresh

- When Claude's page has no readable quota layout, try one bounded structured
  usage read in that same account's isolated WebKit session.
- Keep actual session, weekly and model-specific windows separate. No missing
  limit becomes a synthetic 100% or unlimited quota.
- A successful structured response explicitly reporting no quota windows clears
  old bars and shows **No usage limits reported**, without guessing the plan.
- Keep authentication failures, denied/rate-limited requests, malformed replies
  and ambiguous workspaces distinct from no-quota responses. Never select the
  first arbitrary workspace or reset sign-in data.
- Existing successful page reads do not make additional API requests. The
  fallback has a single eight-second deadline, at most two read-only requests,
  strict origin/schema checks and bounded response sizes.
- Debug reports add only fixed outcome/stage/status facts, not API bodies,
  account IDs, quota values or chat contents. Nothing is uploaded automatically.

Tested with isolated quota, no-quota, access-error, multi-account and cancellation
fixtures. Confirmation on affected remote accounts remains outstanding. Provider
web endpoints are undocumented and can change; unsupported replies remain errors.

## Robustere Claude-Aktualisierung

Wenn die Claude-Seite keine auslesbaren Limit-Abschnitte liefert, kann Token
Monitor die strukturierten Nutzungsdaten innerhalb derselben Kontositzung lesen.
Bestätigt Claude ausdrücklich, dass keine Limits geliefert werden, verschwinden
die alten Balken zugunsten eines klaren Hinweises. Das bedeutet weder unbegrenzte
Nutzung noch eine automatische Erkennung des Abos. Zugriffsfehler werden nicht
als fehlende Limits ausgegeben. Bestehende Anmeldungen bleiben erhalten.
