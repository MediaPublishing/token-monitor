#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
DMG_PATH="$ROOT_DIR/dist/TokenMonitor-macOS.dmg"
DMG_ROOT="$ROOT_DIR/dist/dmg-root"
VOLUME_NAME="Token Monitor"

cd "$ROOT_DIR"

if [[ "${TOKEN_MONITOR_SKIP_BUILD:-}" != "1" ]]; then
  "$ROOT_DIR/scripts/build-app.sh"
fi

if [[ ! -d "$APP_DIR" ]]; then
  printf 'Missing app bundle: %s\n' "$APP_DIR" >&2
  exit 1
fi

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

ditto "$APP_DIR" "$DMG_ROOT/TokenMonitor.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_ROOT"

shasum -a 256 "$DMG_PATH"
printf 'Packaged %s\n' "$DMG_PATH"
