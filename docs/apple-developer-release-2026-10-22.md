# Apple-Developer-Releasevorbereitung, 22.10.2026

Status: lokale Vorbereitung und Test-DMG fertig; Developer-ID-Signing und Notarisierung blockiert.
Kanonisches Repo: `/Users/MediaPublishing/Projects/token-monitor` (Ausgangs-HEAD `e626e81`).
Bestehender Hauptweg bleibt Developer-ID-DMG plus Sparkle. Der vorbereitete MAS-Zweig wird
nicht aktiviert. Version 1.0.47 (56) bleibt unverändert.

## Änderungen

- `packaging/apple-developer-team-id.txt` bindet Developer-ID-Prüfungen an F7ZC4PZ39V.
- `build-app.sh` prüft eine angegebene Identität vor dem Build. Sparkle-XPCs, Autoupdate und
  Updater.app werden unter Erhalt ihrer Entitlements von innen nach außen signiert.
  `apple-distribution.py` prüft Apple-Vertrauen, Team, Runtime, Zeitstempel, sämtliche
  Mach-O-Dateien sowie unveränderte Bundle-/Update-Identität. Keine neuen Entitlements.
- `package-dmg.sh` notarisiert und stapelt zuerst die App und anschließend das DMG.
  `package-release.sh` erzeugt GitHub- und Sparkle-ZIP erst danach aus der identischen App.
  Nur explizites Apple `Accepted` erlaubt Stapling. Strikte Releaseprüfung kontrolliert
  auch die entpackten ZIP-Apps samt Ticket. Vorhandene Receipts werden nicht überschrieben.
- `TOKEN_MONITOR_DIST_DIR` ermöglicht einen getrennten Kandidatenpfad; vorhandene `dist`-
  Releases und die laufende `/Applications/TokenMonitor.app` bleiben erhalten.
- Historische Release-Workflow-Rebuilds holen die zusammengehörigen neuen Skripte und den
  Team-Pin gemeinsam. Workflow nicht ausgelöst, keine GitHub-Secrets/Variablen verändert.
- Veraltetes `notarytool history --limit` entfernt; aktuelle CLI unterstützt diesen Schalter nicht.

## Tests und lokale Artefakte

158 vorhandene Swift-Tests in 18 Suiten bestanden. Die Suite führt zusätzlich die fünf
Offline-Signing-/Notarisierungsprüfungen aus. Release-Build, `codesign --verify --deep --strict`,
Shell-Syntax, Versionskonsistenz und Repo-Hygiene bestanden. Kein Produkt-UI geändert;
der Startup-Smoke-Test ist laut Skript ausschließlich für isoliertes CI, daher lokal nicht
gegen die laufende echte Installation ausgeführt.

Lokale Testartefakte, ausdrücklich **Ad-hoc-signiert und nicht notarisiert**:

- `dist/apple-membership-20261022/TokenMonitor.app`
- `dist/apple-membership-20261022/TokenMonitor-macOS.dmg`
- DMG SHA-256: `f5015cfee8d803adf5b75bff3df55dc703848e373ef684f451215dec62f1276b`

Sie dienen nur der Packaging-Abnahme und sind kein freigabefähiger Apple-Release.
Logs und Vorherstände: `dist/apple-membership-20261022/receipts/`.
Vorbestehende Dateien `docs/popover-layout-spec-2026-10-12.md` und `docs/prototypes/` bleiben erhalten.

## Nächster lokaler Schritt nach Zertifikateinrichtung

```sh
TOKEN_MONITOR_CODESIGN_IDENTITY='<EXISTING_DEVELOPER_ID_NAME_OR_SHA1>' \
TOKEN_MONITOR_DIST_DIR="$PWD/dist/apple-signed-candidate" \
TOKEN_MONITOR_BUILD_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
TOKEN_MONITOR_BUILD_JOBS=2 ./scripts/build-app.sh
```

Das erzeugt nur `dist/apple-signed-candidate/TokenMonitor.app`. Dieser konkrete Kandidat muss
zuerst vorgelegt werden. Erst nach separater Uploadfreigabe darf `package-release.sh` mit
`TOKEN_MONITOR_NOTARIZE=1`, bestehendem Profil und `--require-distribution-ready` laufen:
es überträgt das ZIP der signierten App und das fertige `TokenMonitor-macOS.dmg` an Apple.
Danach entstehen die Sparkle-Artefakte mit dem bereits vorhandenen EdDSA-Schlüssel.
Vor dem öffentlichen Release Buildnummer erhöhen und Migration aus dem alten Preview-Build
praktisch prüfen. Bundle-ID `com.mediapublishing.tokenmonitor`, Feed, EdDSA-Schlüssel,
WebKit-Sitzungen und Datenpfade bleiben unverändert.

Das dokumentierte Profil `token-monitor-notary` wurde gezielt per `notarytool history`
geprüft: „No Keychain password item found for profile“. Es wurde nicht angelegt.
Die komplette Profilinventur ist nicht belegt: Eine breite `security dump-keychain`-
Metadatenabfrage wurde vor Ausführung durch Auto-Review abgelehnt. Kein Umgehungsversuch;
die erfolgreiche eng begrenzte Alternative bestätigt das Fehlen des dokumentierten Profils.

## Bestätigter Account und Freigabegrenzen

Am 22.10.2026 im bestehenden Comet-Login unter https://developer.apple.com/account gelesen:
Organisation **Reto Stuber Global Headquarters LLC**, Team **F7ZC4PZ39V**, Apple Developer Program,
Rolle Account Holder, Verlängerung 22.10.2027. Die Zertifikatliste zeigt „Getting Started with
Certificates“, keine vorhandenen Zertifikate. `security find-identity -v -p codesigning`:
**0 gültige Identitäten**. Vorhanden ist lediglich das bisherige lokale Voice-Zertifikat,
das keine Apple Developer ID ist. Mitgliedschaft allein macht keinen Release signierbar.

Keine Zertifikate, privaten Schlüssel, API-Keys, Notarisierungsprofile oder GitHub-Secrets
angelegt/importiert, keine Rechte verändert, keine Verträge akzeptiert. Keine Notarisierungs-
Uploads, Veröffentlichungen, Pushes oder App-Installation durchgeführt. Bestehende Release-
Versionen und Update-Schlüssel bleiben unverändert. Die Team-Datei enthält nur öffentliche
Signing-Metadaten und erteilt keine neue Zugangs- oder Uploadfreigabe.

Die konkrete Erstellung und Einrichtung eines **Developer ID Application**-Zertifikats
samt privatem Schlüssel für Team F7ZC4PZ39V im Login-Schlüsselbund dieses Macs ist seit
22.10.2026, 04:31 UTC ausdrücklich freigegeben. Dafür ist keine erneute Freigabe nötig.
Die Ausführung ist derzeit technisch blockiert (siehe Nachtrag unten).
Separat zu bestätigen bleiben der konkrete Notarisierungszugang und dessen Speicherung
als benanntes lokales Keychain-Profil sowie danach die konkreten App-/DMG-Uploads.
Kein Developer ID Installer nötig für diese DMGs; kein App-Store-Wechsel.
GitHub-Credential-Export und CI-Secrets sind ein eigener, hier nicht freigegebener Schritt.

Nach vorhandenem Zertifikat zuerst lokal signieren und prüfen. Anschließend die genauen
Artefaktpfade und SHA-256-Werte vorlegen und **deren Upload an Apples Notary Service über
`xcrun notarytool submit`** ausdrücklich freigeben lassen. Apple `Accepted`, Stapling und
Gatekeeper-Prüfung müssen bestehen, bevor ein weiterer, separat freigegebener Release erfolgt.
Bisher gibt es kein Apple-signiertes, zur Notarisierung freizugebendes Artefakt.

## Quellen

- [Apple: Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Sparkle: Signing keys and distribution](https://sparkle-project.org/documentation/)

## Nachtrag: bestätigte Zertifikatseinrichtung, 22.10.2026, 05:16 UTC

Die bestehende Apple-Sitzung zeigte erneut Team F7ZC4PZ39V und eine leere Zertifikatliste.
Im Erstellungsassistenten wurde ausschließlich der Typ Developer ID Application ausgewählt.
Ein CSR wurde weder erzeugt noch hochgeladen; Apples abschließende Erstellung wurde nicht
ausgeführt. Es wurden keine neuen Schlüssel oder Zertifikate erzeugt/importiert.

Der Aufruf zum Öffnen von Keychain Access brach nach langer Wartezeit mit
`Transport closed` ab. Sein reiner Fensteröffnungszustand war ungewiss; es war kein
Erstellungsschritt. Ein anschließender lesender UI-Aufruf und der Verbindungsreset scheiterten
ebenfalls sofort. Die separate CLI-Prüfung um 05:16 UTC funktionierte:
`security find-identity -v -p codesigning` meldete erneut 0 gültige Identitäten;
`security find-certificate -a -c 'Developer ID Application' -Z` lieferte keine Einträge.
Kein Build-, Codesign- oder Notary-Prozess lief bei der anschließenden Prozessprüfung.

Blocker ist der nicht verfügbare Computer-Use-Dienst, keine abgelehnte Zertifikatsfreigabe
und kein bestätigter Passwortdialog. Nach Wiederherstellung der UI-Verbindung zuerst
Portal und lokale Identitäten erneut prüfen, dann mit der vorhandenen Freigabe den CSR
in Keychain Access erstellen (privater Schlüssel bleibt im Login-Schlüsselbund), im
Apple-Portal G2 Sub-CA wählen, ausschließlich den öffentlichen CSR hochladen und das
öffentliche Zertifikat installieren. Kein privater Schlüsselexport. Danach lokal signieren
und prüfen. Notarisierungszugang und App-Artefakt-Uploads bleiben gesondert freizugeben.
Noch kein Apple-signierter Kandidat vorhanden; beide Apps bleiben nicht releasebereit.

## Wiederanlauf: 22.10.2026, Stand 11:42 UTC

Nach gemeldeter Wiederverbindung funktionierten Computer-Use-Inventur und Comet-UI erneut.
Die bestehende Apple-Seite wurde auf die Zertifikatliste zurückgeführt: Team F7ZC4PZ39V,
erneut keine Zertifikate. Auch die gezielte lokale Vorprüfung ergab 0 gültige Identitäten.
Es wurde kein neuer Antrag begonnen oder abgeschickt.

Der folgende Aufruf zum Öffnen von `com.apple.keychainaccess` blieb trotz angeforderter
20-Sekunden-Laufzeitgrenze hängen und endete erst nach rund 6 Stunden 21 Minuten erneut
mit `Transport closed`. Dieser Aufruf kann nur die App öffnen; kein CSR-/Schlüsselerstellungs-
oder Zertifikatsimportschritt wurde aufgerufen. Der App-Öffnungszustand ist ungewiss.
Kein blindes Wiederholen des UI-Aufrufs. Die erfolgreiche CLI-Nachprüfung um
2026-10-22T11:42:24Z meldete weiterhin 0 gültige Signing-Identitäten und keine
Developer-ID-Application-Zertifikate.

Kleinster Wiederherstellungsschritt: Computer-Use-Verbindung erneut herstellen und die
Schlüsselbundverwaltung einmal direkt am Mac öffnen. Anschließend zunächst nur das
vorhandene Fenster lesen und lokale Identitäten/Apple-Liste auf Dubletten prüfen, bevor
der bereits genehmigte CSR-/Zertifikatsablauf fortgesetzt wird. Der Browserzugriff allein
belegt keine funktionierende Steuerung der Schlüsselbundverwaltung. Keine neue allgemeine
Freigabe erforderlich. Ohne erreichbare Schlüsselbund-UI bleiben Zertifikat und lokale
Developer-ID-Signierung beider Kandidaten ausstehend. Keine App-Uploads oder Veröffentlichung.
