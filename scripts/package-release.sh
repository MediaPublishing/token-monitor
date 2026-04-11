#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
ZIP_PATH="$ROOT_DIR/dist/TokenMonitor-macOS.zip"
DMG_PATH="$ROOT_DIR/dist/TokenMonitor-macOS.dmg"
UPDATES_DIR="$ROOT_DIR/dist/updates"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"
SPARKLE_BIN_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
DOWNLOAD_URL_PREFIX="${TOKEN_MONITOR_DOWNLOAD_URL_PREFIX:-https://mediapublishing.github.io/token-monitor/updates/}"

"$ROOT_DIR/scripts/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist")"
VERSIONED_ZIP_PATH="$UPDATES_DIR/TokenMonitor-${VERSION}-${BUILD_NUMBER}-macOS.zip"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
TOKEN_MONITOR_SKIP_BUILD=1 "$ROOT_DIR/scripts/package-dmg.sh"

mkdir -p "$UPDATES_DIR"
cp "$ZIP_PATH" "$VERSIONED_ZIP_PATH"

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN_DIR/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    "$UPDATES_DIR"
elif [[ "${TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY:-}" == "1" ]]; then
  "$SPARKLE_BIN_DIR/generate_appcast" \
    --account token-monitor \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    "$UPDATES_DIR"
else
  cat >&2 <<'EOF'
Missing Sparkle signing key.
Set SPARKLE_PRIVATE_KEY to the exported private key, or set
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 to sign with the local keychain
account named token-monitor.
EOF
  exit 1
fi

cp "$UPDATES_DIR/appcast.xml" "$APPCAST_PATH"

shasum -a 256 "$ZIP_PATH"
shasum -a 256 "$DMG_PATH"
shasum -a 256 "$VERSIONED_ZIP_PATH" "$APPCAST_PATH"
printf 'Packaged %s\n' "$ZIP_PATH"
printf 'Installer %s\n' "$DMG_PATH"
printf 'Update archive %s\n' "$VERSIONED_ZIP_PATH"
printf 'Appcast %s\n' "$APPCAST_PATH"
