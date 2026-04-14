# Token Monitor

**Token Monitor** is a native macOS menu bar companion for Claude and ChatGPT/Codex usage: provider-specific limits, isolated sessions, background refresh, and Sparkle-ready update checks in one lightweight desktop app.

**Token Monitor** ist ein nativer macOS-Menüleisten-Begleiter für Claude- und ChatGPT/Codex-Nutzung: provider-spezifische Limits, getrennte Sessions, Hintergrund-Refresh und vorbereitete Sparkle-Updates in einer schlanken Desktop-App.

<p>
  <a href="https://github.com/MediaPublishing/token-monitor/releases/latest/download/TokenMonitor-macOS.dmg">
    <img alt="Download" src="https://img.shields.io/badge/Download-DMG-0A7CFF?style=for-the-badge&logo=apple&logoColor=white">
  </a>
</p>

> **Repository status / Repository-Status:** Public preview.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6+](https://img.shields.io/badge/Swift-6%2B-orange)
![Updates](https://img.shields.io/badge/updates-Sparkle-green)

## Screenshots

### Dashboard
![Token Monitor dashboard screenshot](assets/screenshots/app/dashboard.png)

Watch Claude and ChatGPT/Codex side by side from the macOS menu bar.

Claude und ChatGPT/Codex bleiben direkt in der macOS-Menüleiste nebeneinander sichtbar.

### Claude Usage
![Token Monitor Claude usage screenshot](assets/screenshots/app/claude.png)

Keep Claude usage source-native: session, model, Sonnet, balance, extra usage, and reset timing stay separate.

Claude bleibt quellnah: Session, Modell, Sonnet, Balance, Extra Usage und Reset-Zeit werden getrennt angezeigt.

### ChatGPT + Codex Usage
![Token Monitor ChatGPT usage screenshot](assets/screenshots/app/chatgpt.png)

Track ChatGPT daily, weekly, Codex, and credit limits without digging through browser tabs.

ChatGPT Daily, Weekly, Codex und Credits bleiben sichtbar, ohne Browser-Tab-Suche.

---

## English

### Why Token Monitor

If your work depends on Claude and ChatGPT, the limiting factor is often not the model quality but whether you still have room left in the current window. Token Monitor closes that gap from the menu bar.

- View Claude and ChatGPT/Codex in one compact popover
- Keep each provider in its own persistent WebKit session
- Refresh on launch, on demand, and in the background
- Preserve source-native metrics instead of inventing a combined score
- Use the menu bar icon as a quick remaining-capacity signal
- Check for updates through Sparkle and the project appcast

### Requirements

- macOS 14.0 or newer
- Swift 6 toolchain / Command Line Tools for source builds
- Claude and/or ChatGPT account access

### Installation

Normal users should install from the GitHub Release DMG:

1. Download `TokenMonitor-macOS.dmg` from the latest release.
2. Open the disk image.
3. Drag `TokenMonitor.app` onto the Applications shortcut.
4. Open Token Monitor and connect Claude and ChatGPT from Settings.

Latest release download:

```text
https://github.com/MediaPublishing/token-monitor/releases/latest/download/TokenMonitor-macOS.dmg
```

Gatekeeper note: preview builds may show Apple's "could not verify" warning until the app is Developer ID signed and notarized. Only bypass Gatekeeper for a build you downloaded from this repository and trust; public releases should move to notarized builds before broader distribution.

### Updates

Token Monitor is wired for Sparkle update checks. The appcast URL baked into the app is:

```text
https://mediapublishing.github.io/token-monitor/appcast.xml
```

When a GitHub Release is published, `.github/workflows/release.yml` can rebuild the app, upload `TokenMonitor-macOS.dmg` and `TokenMonitor-macOS.zip` to the release, and deploy `appcast.xml` plus the versioned update ZIP to GitHub Pages.

The GitHub workflow uses repository secret `SPARKLE_PRIVATE_KEY`. Maintainers can create a local release build with the Keychain entry instead:

```bash
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 ./scripts/package-release.sh
```

For public distribution at scale, sign and notarize the app before publishing.

### Build From Source

```bash
git clone https://github.com/MediaPublishing/token-monitor.git
cd token-monitor
swift build
swift run TokenMonitorApp
```

Run the app directly through the project script:

```bash
./scripts/run-app.sh
```

Create a local app bundle:

```bash
./scripts/build-app.sh
open dist/TokenMonitor.app
```

Create a release ZIP and signed appcast:

```bash
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 ./scripts/package-release.sh
```

Create only the local DMG installer:

```bash
./scripts/package-dmg.sh
```

### Privacy

Token Monitor stores only the latest successful usage snapshots locally at `~/Library/Application Support/TokenMonitor/snapshots.json`. Each provider uses its own persistent WebKit session, so Claude and ChatGPT login state stay isolated from each other and from your normal browser cookies.

---

## Deutsch

### Warum Token Monitor

Wenn deine Arbeit von Claude und ChatGPT abhängt, ist oft nicht die Modellqualität der Engpass, sondern ob im aktuellen Fenster noch Kapazität übrig ist. Token Monitor schließt genau diese Lücke in der Menüleiste.

- Claude und ChatGPT/Codex in einem kompakten Popover sehen
- Jeden Provider in einer eigenen persistenten WebKit-Session halten
- Beim Start, manuell und im Hintergrund aktualisieren
- Quellnahe Metriken behalten statt einen künstlichen Gesamtscore zu bauen
- Das Menüleisten-Icon als schnelles Restkapazitäts-Signal nutzen
- Updates über Sparkle und den Projekt-Appcast prüfen

### Voraussetzungen

- macOS 14.0 oder neuer
- Swift 6 Toolchain / Command Line Tools für Source-Builds
- Claude- und/oder ChatGPT-Account-Zugriff

### Installation

Normale Nutzer sollten über das GitHub-Release-DMG installieren:

1. `TokenMonitor-macOS.dmg` aus dem neuesten Release herunterladen.
2. Disk Image öffnen.
3. `TokenMonitor.app` auf die Applications-Verknüpfung ziehen.
4. Token Monitor öffnen und Claude sowie ChatGPT in den Settings verbinden.

Aktueller Release-Download:

```text
https://github.com/MediaPublishing/token-monitor/releases/latest/download/TokenMonitor-macOS.dmg
```

Gatekeeper-Hinweis: Preview-Builds können Apples "konnte nicht überprüfen"-Warnung zeigen, bis die App mit Developer ID signiert und notarized ist. Umgehe Gatekeeper nur bei einem Build, den du aus diesem Repository geladen hast und dem du vertraust; öffentliche Releases sollten vor breiterer Verteilung notarized Builds nutzen.

### Updates

Token Monitor ist für Sparkle-Update-Checks vorbereitet. Die in der App hinterlegte Appcast-URL ist:

```text
https://mediapublishing.github.io/token-monitor/appcast.xml
```

Wenn ein GitHub Release veröffentlicht wird, kann `.github/workflows/release.yml` die App neu bauen, `TokenMonitor-macOS.dmg` und `TokenMonitor-macOS.zip` in das Release hochladen und `appcast.xml` plus versioniertes Update-ZIP auf GitHub Pages deployen.

Der GitHub Workflow nutzt das Repository-Secret `SPARKLE_PRIVATE_KEY`. Maintainer können einen lokalen Release-Build mit dem Keychain-Eintrag erstellen:

```bash
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 ./scripts/package-release.sh
```

Für öffentliche Verteilung in größerem Umfang sollte die App vor dem Release signiert und notarisiert werden.

### Aus dem Source Code bauen

```bash
git clone https://github.com/MediaPublishing/token-monitor.git
cd token-monitor
swift build
swift run TokenMonitorApp
```

App direkt über das Projektskript starten:

```bash
./scripts/run-app.sh
```

Lokales App-Bundle erstellen:

```bash
./scripts/build-app.sh
open dist/TokenMonitor.app
```

Release-ZIP und signierten Appcast erstellen:

```bash
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 ./scripts/package-release.sh
```

Nur den lokalen DMG-Installer erstellen:

```bash
./scripts/package-dmg.sh
```

### Datenschutz

Token Monitor speichert nur die letzten erfolgreichen Usage-Snapshots lokal unter `~/Library/Application Support/TokenMonitor/snapshots.json`. Jeder Provider nutzt eine eigene persistente WebKit-Session, damit Claude- und ChatGPT-Login getrennt bleiben und keine normalen Browser-Cookies verwendet werden.

---

## Project Structure

```text
token-monitor/
├── Package.swift
├── Sources/TokenMonitorApp/
├── Sources/TokenMonitorCore/
├── Tests/TokenMonitorCoreTests/
├── assets/
├── docs/
├── landing/
└── scripts/
```

## Documentation

- [Landing page](landing/index.html)
- [Current screenshot](docs/token-monitor-screenshot.png)

## License

License information is not published in this repository yet.
