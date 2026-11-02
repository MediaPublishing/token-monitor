#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${TOKEN_MONITOR_DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/TokenMonitor.app"
DMG_PATH="$DIST_DIR/TokenMonitor-macOS.dmg"
DMG_ROOT="$DIST_DIR/dmg-root"
VOLUME_NAME="Token Monitor"
CODESIGN_IDENTITY="${TOKEN_MONITOR_CODESIGN_IDENTITY:--}"

cd "$ROOT_DIR"

if [[ "${TOKEN_MONITOR_NOTARIZE:-0}" == "1" ]]; then
  [[ -n "${TOKEN_MONITOR_NOTARY_PROFILE:-}" ]] || { printf 'Missing TOKEN_MONITOR_NOTARY_PROFILE\n' >&2; exit 1; }
  python3 "$ROOT_DIR/scripts/apple-distribution.py" identity "$CODESIGN_IDENTITY"
fi

if [[ "${TOKEN_MONITOR_SKIP_BUILD:-}" != "1" ]]; then
  "$ROOT_DIR/scripts/build-app.sh"
fi

if [[ ! -d "$APP_DIR" ]]; then
  printf 'Missing app bundle: %s\n' "$APP_DIR" >&2
  exit 1
fi

if [[ "${TOKEN_MONITOR_NOTARIZE:-0}" == "1" ]]; then
  python3 "$ROOT_DIR/scripts/apple-distribution.py" notarize "$APP_DIR" \
    --profile "$TOKEN_MONITOR_NOTARY_PROFILE" --receipt "$DIST_DIR/notarization-app.json"
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

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --strict "$DMG_PATH"
fi

if [[ "${TOKEN_MONITOR_NOTARIZE:-0}" == "1" ]]; then
  python3 "$ROOT_DIR/scripts/apple-distribution.py" notarize "$DMG_PATH" \
    --profile "$TOKEN_MONITOR_NOTARY_PROFILE" --receipt "$DIST_DIR/notarization-dmg.json"
fi

rm -rf "$DMG_ROOT"

shasum -a 256 "$DMG_PATH"
printf 'Packaged %s\n' "$DMG_PATH"
