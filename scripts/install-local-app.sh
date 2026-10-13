#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/dist/TokenMonitor.app"
TARGET="/Applications/TokenMonitor.app"
IDENTIFIER="com.mediapublishing.tokenmonitor"
MODE="${1:-install}"
if [[ "$MODE" != install && "$MODE" != --check ]]; then
    printf 'Usage: %s [--check]\n' "$0" >&2
    exit 1
fi

bundle_id() { /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"; }
[[ "$(bundle_id "$SOURCE")" == "$IDENTIFIER" ]] || { printf 'Unexpected source app identifier.\n' >&2; exit 1; }
if [[ -e "$TARGET" ]]; then
    [[ "$(bundle_id "$TARGET")" == "$IDENTIFIER" ]] || { printf 'Refusing to replace a different app.\n' >&2; exit 1; }
fi
codesign --verify --deep --strict "$SOURCE"
if [[ "$MODE" == --check ]]; then
    printf 'PASS: signed local candidate and matching app identifier; no changes made.\n'
    exit 0
fi

BACKUP="$HOME/AI/backups/token-monitor/local-install-$(date +%Y%m%d-%H%M%S)-$$"
PREVIOUS="$BACKUP/TokenMonitor.previous"
STAGED="$BACKUP/TokenMonitor.candidate"
mkdir -p "$BACKUP"
ditto "$SOURCE" "$STAGED"
codesign --verify --deep --strict "$STAGED"

rollback() {
    local result=$?
    if [[ "$result" != 0 && -e "$PREVIOUS" ]]; then
        if [[ -e "$TARGET" ]]; then mv "$TARGET" "$BACKUP/TokenMonitor.failed"; fi
        mv "$PREVIOUS" "$TARGET"
        open "$TARGET"
    fi
}
trap rollback EXIT

pids="$(pgrep -f '^/Applications/TokenMonitor[.]app/Contents/MacOS/TokenMonitorApp($| )' || true)"
for pid in $pids; do kill -TERM "$pid"; done
for attempt in {1..20}; do
    if ! pgrep -f '^/Applications/TokenMonitor[.]app/Contents/MacOS/TokenMonitorApp($| )' >/dev/null; then break; fi
    sleep 0.2
done
if pgrep -f '^/Applications/TokenMonitor[.]app/Contents/MacOS/TokenMonitorApp($| )' >/dev/null; then
    printf 'App did not quit; the installed app is unchanged.\n' >&2
    exit 1
fi

# Keep the old bundle outside Trash so app cleaners cannot offer to delete its sign-in data.
if [[ -e "$TARGET" ]]; then mv "$TARGET" "$PREVIOUS"; fi
mv "$STAGED" "$TARGET"
open "$TARGET"
trap - EXIT
printf 'Installed %s. Previous app: %s\n' "$TARGET" "$PREVIOUS"
printf 'Account settings and WebKit data were not read, copied or removed.\n'
