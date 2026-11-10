# Token Monitor 1.0.54

<!-- token-monitor:prebuilt-notarized -->

## Private Refresh Diagnostics

- Replace raw page previews with fixed technical recognition facts: page category and whether known headings, percentages, resets, login or challenge markers are present.
- New refresh records omit page text, chat titles, URLs, dynamic page titles and free-form error messages.
- Debug exports use numbered provider-account aliases instead of configured names or stable account IDs.
- Older records are filtered when read and exported. Previously saved raw JSON/text files are not silently deleted or rewritten and should not be shared.
- Save Debug Report creates a private local file. Save Performance Report remains a separate action for CPU/resource problems. Email and GitHub drafts are under Drafts and use the same privacy-filtered renderer.
- Debugging remains opt-in; no automatic upload or message. Existing accounts and sign-ins are unchanged.
- This update improves diagnostic privacy. It does not claim to fix unresolved provider-page parsing failures.

## Datensparsame Fehlerberichte

Neue Diagnoseprotokolle speichern keine Seiteninhalte, Chat-Titel, URLs oder freien
Fehlermeldungen mehr. Stattdessen enthalten sie feste technische Erkennungsmerkmale.
Kontonamen und Konto-IDs werden im Bericht durch nummerierte Anbieter-Aliase ersetzt.
Auch ältere Einträge werden vor einem neuen Export bereinigt. Bereits gespeicherte
Rohdateien bleiben unverändert und sollten nicht geteilt werden.

Mit Save Debug Report lässt sich der Auslesebericht direkt lokal speichern; der
Performance-Bericht bleibt getrennt. Es wird nichts automatisch versendet. Der
ursprüngliche Auslesefehler ist damit noch nicht als behoben bestätigt.
