# Token Monitor

**Token Monitor** is a native macOS menu bar companion for Claude and ChatGPT/Codex usage: provider-specific limits, isolated sessions, and background refresh in one lightweight desktop app.

**Token Monitor** ist ein nativer macOS-Menüleisten-Begleiter für Claude- und ChatGPT/Codex-Nutzung: provider-spezifische Limits, getrennte Sessions und Hintergrund-Refresh in einer schlanken Desktop-App.

<p>
  <a href="https://github.com/MediaPublishing/token-monitor/releases/latest/download/TokenMonitor-macOS.dmg">
    <img alt="Download" src="https://img.shields.io/badge/Download-DMG-0A7CFF?style=for-the-badge&logo=apple&logoColor=white">
  </a>
</p>

> **Repository status / Repository-Status:** Public preview.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6+](https://img.shields.io/badge/Swift-6%2B-orange)

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

#### Gatekeeper: If macOS says "TokenMonitor.app" Not Opened

Preview builds may show Apple's "could not verify" warning until the app is Developer ID signed and notarized. Only continue if you downloaded the DMG from this repository and trust that build.

1. Click **Done**, not **Move to Trash**.
2. Open **System Settings > Privacy & Security**.
3. Scroll to **Security**.
4. Find the message that `TokenMonitor.app` was blocked and click **Open Anyway**.
5. Confirm with your Mac password or Touch ID, then click **Open**.

Visual walkthrough:

| Step 1 | Step 2 |
| --- | --- |
| Click **Done**, not **Move to Trash**. | Open **System Settings > Privacy & Security** and click **Open Anyway**. |
| ![Gatekeeper warning with Done button](assets/screenshots/install/gatekeeper-blocked.png) | ![Privacy and Security Open Anyway button](assets/screenshots/install/gatekeeper-privacy-security.png) |

| Step 3 | Step 4 |
| --- | --- |
| Confirm by clicking **Open Anyway**. | Enter your Mac password or use Touch ID, then click **OK**. |
| ![Open Anyway confirmation dialog](assets/screenshots/install/gatekeeper-open-anyway.png) | ![Privacy and Security password confirmation dialog](assets/screenshots/install/gatekeeper-admin-confirm.png) |

macOS stores this exception for Token Monitor, so future launches should open normally. If **Open Anyway** is not visible, try opening `TokenMonitor.app` once more, then return to **Privacy & Security**. Apple's official guide is here: <https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac>

#### Launch at login

Token Monitor tries to register itself as a login item when **Launch at login** is enabled in Settings. macOS requires apps that use Apple's ServiceManagement login-item API to be code signed, so ad-hoc preview builds may not appear under **System Settings > General > Login Items**. Move `TokenMonitor.app` to **Applications**, open it once, then use **Settings > Launch at login** inside Token Monitor. If macOS still requires approval, open **Login Items** from Token Monitor Settings and allow Token Monitor there.

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

Create only the local DMG installer:

```bash
./scripts/package-dmg.sh
```

### Privacy

Token Monitor stores only the latest successful usage snapshots locally at `~/Library/Application Support/TokenMonitor/snapshots.json`. Each provider uses its own persistent WebKit session, so Claude and ChatGPT login state stay isolated from each other and from your normal browser cookies.

Debug mode is off by default. When enabled in Settings, Token Monitor stores redacted refresh diagnostics locally in `~/Library/Application Support/TokenMonitor/Debug/`. Reports open only as drafts for GitHub Issues or email, so you can review them before submitting. GitHub Issues are public.

---

## Deutsch

### Warum Token Monitor

Wenn deine Arbeit von Claude und ChatGPT abhängt, ist oft nicht die Modellqualität der Engpass, sondern ob im aktuellen Fenster noch Kapazität übrig ist. Token Monitor schließt genau diese Lücke in der Menüleiste.

- Claude und ChatGPT/Codex in einem kompakten Popover sehen
- Jeden Provider in einer eigenen persistenten WebKit-Session halten
- Beim Start, manuell und im Hintergrund aktualisieren
- Quellnahe Metriken behalten statt einen künstlichen Gesamtscore zu bauen
- Das Menüleisten-Icon als schnelles Restkapazitäts-Signal nutzen

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

#### Gatekeeper: Wenn macOS "TokenMonitor.app" nicht öffnet

Preview-Builds können Apples "konnte nicht überprüfen"-Warnung zeigen, bis die App mit Developer ID signiert und notarized ist. Fahre nur fort, wenn du das DMG aus diesem Repository geladen hast und diesem Build vertraust.

1. **Fertig** klicken, nicht **In den Papierkorb legen**.
2. **Systemeinstellungen > Datenschutz & Sicherheit** öffnen.
3. Zu **Sicherheit** scrollen.
4. Die Meldung suchen, dass `TokenMonitor.app` blockiert wurde, und **Dennoch öffnen** klicken.
5. Mit Mac-Passwort oder Touch ID bestätigen, danach **Öffnen** klicken.

Visuelle Schritt-für-Schritt-Anleitung:

| Schritt 1 | Schritt 2 |
| --- | --- |
| **Fertig** klicken, nicht **In den Papierkorb legen**. | **Systemeinstellungen > Datenschutz & Sicherheit** öffnen und **Dennoch öffnen** klicken. |
| ![Gatekeeper-Warnung mit Fertig-Button](assets/screenshots/install/gatekeeper-blocked.png) | ![Datenschutz und Sicherheit mit Dennoch-oeffnen-Button](assets/screenshots/install/gatekeeper-privacy-security.png) |

| Schritt 3 | Schritt 4 |
| --- | --- |
| Mit **Open Anyway** bestätigen. | Mac-Passwort eingeben oder Touch ID nutzen, danach **OK** klicken. |
| ![Open-Anyway-Bestaetigungsdialog](assets/screenshots/install/gatekeeper-open-anyway.png) | ![Datenschutz-und-Sicherheit-Passwortbestaetigung](assets/screenshots/install/gatekeeper-admin-confirm.png) |

macOS speichert diese Ausnahme für Token Monitor, danach sollte die App normal starten. Wenn **Dennoch öffnen** nicht sichtbar ist, öffne `TokenMonitor.app` noch einmal und gehe danach wieder zu **Datenschutz & Sicherheit**. Apples offizielle Anleitung: <https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac>

#### Beim Login starten

Token Monitor versucht, sich als Login Item zu registrieren, wenn **Launch at login** in den Settings aktiv ist. macOS verlangt für Apps mit Apples ServiceManagement-Login-Item-API eine Code-Signatur, deshalb erscheinen ad-hoc signierte Preview-Builds möglicherweise nicht unter **Systemeinstellungen > Allgemein > Anmeldeobjekte**. Verschiebe `TokenMonitor.app` nach **Applications**, öffne die App einmal und nutze danach **Settings > Launch at login** in Token Monitor. Wenn macOS weiterhin eine Freigabe verlangt, öffne **Anmeldeobjekte** aus den Token-Monitor-Settings und erlaube Token Monitor dort.

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

Nur den lokalen DMG-Installer erstellen:

```bash
./scripts/package-dmg.sh
```

### Datenschutz

Token Monitor speichert nur die letzten erfolgreichen Usage-Snapshots lokal unter `~/Library/Application Support/TokenMonitor/snapshots.json`. Jeder Provider nutzt eine eigene persistente WebKit-Session, damit Claude- und ChatGPT-Login getrennt bleiben und keine normalen Browser-Cookies verwendet werden.

Der Debug-Modus ist standardmäßig aus. Wenn er in den Einstellungen aktiviert wird, speichert Token Monitor redigierte Refresh-Diagnosen lokal unter `~/Library/Application Support/TokenMonitor/Debug/`. Reports werden nur als GitHub-Issue- oder E-Mail-Entwurf geöffnet, damit du sie vor dem Absenden prüfen kannst. GitHub Issues sind öffentlich.

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
- [Apple distribution readiness](docs/apple-distribution-readiness.md)
- [Marketing launch kit](docs/marketing-launch-kit.md)

## License

License information is not published in this repository yet.
