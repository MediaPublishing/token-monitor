#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BUILD_DIR/TokenMonitorApp" "$MACOS_DIR/TokenMonitorApp"
chmod +x "$MACOS_DIR/TokenMonitorApp"

codesign --force --sign - "$APP_DIR" >/dev/null

printf 'Built %s\n' "$APP_DIR"
