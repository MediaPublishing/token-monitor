# Token Monitor 1.0.53

<!-- token-monitor:prebuilt-notarized -->

## Account-specific refresh diagnostics

- Debug reports now distinguish accounts of the same provider by account ID and name.
- A successful refresh of another account no longer erases the failed account's diagnostic record.
- The last failed refresh is retained through recovery and restart. Reports include timestamps; an older retained failure is not the current status.
- Diagnostics remain opt-in. Records are redacted and stored locally with private file permissions.
- This is a diagnostic update, not a confirmed fix for every unsupported usage-page layout. If refresh still fails, enable Debugging, refresh the affected accounts and send the Debug Report / Email Draft after reviewing it for private page text. Save Performance Report is for CPU/resource problems, not this layout diagnosis.
- Existing accounts, sign-ins, limit display and update key are preserved. Developer ID signed and notarized by Apple.

## Kontogenaue Fehlerberichte

Der Debug-Bericht ordnet Abrufe jetzt dem jeweiligen Konto zu. Erfolgreiche Abrufe
überschreiben die Fehler anderer Konten nicht mehr. Der letzte Fehler bleibt auch
nach einer Erholung oder einem Neustart erhalten und wird mit Zeitstempel angezeigt.
Debugging bleibt freiwillig und lokal. Dies ist ein Diagnose-Update, kein bestätigter
Fix für alle unbekannten Seitenlayouts. Bei einem erneuten Fehler bitte Debugging
einschalten, betroffene Konten aktualisieren und den Debug-Bericht / E-Mail-Entwurf
nach Prüfung auf private Seiteninhalte schicken, nicht nur den Performance-Bericht.
