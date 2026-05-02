#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/mas/TokenMonitor.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ENTITLEMENTS_PATH="$ROOT_DIR/packaging/TokenMonitorMAS.entitlements"
CODESIGN_IDENTITY="${TOKEN_MONITOR_MAS_CODESIGN_IDENTITY:-${TOKEN_MONITOR_CODESIGN_IDENTITY:--}}"
RESOLVED_PATH="$ROOT_DIR/Package.resolved"
RESOLVED_BACKUP="$(mktemp "${TMPDIR:-/tmp}/token-monitor-package-resolved.XXXXXX")"

restore_package_resolved() {
  if [[ -f "$RESOLVED_BACKUP" ]]; then
    cp "$RESOLVED_BACKUP" "$RESOLVED_PATH"
    rm -f "$RESOLVED_BACKUP"
  fi
}

cp "$RESOLVED_PATH" "$RESOLVED_BACKUP"
trap restore_package_resolved EXIT

cd "$ROOT_DIR"

TOKEN_MONITOR_MAS_BUILD=1 swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Sources/TokenMonitorApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$BUILD_DIR/TokenMonitorApp" "$MACOS_DIR/TokenMonitorApp"
chmod +x "$MACOS_DIR/TokenMonitorApp"

for key in SUFeedURL SUPublicEDKey SUEnableAutomaticChecks SUAllowsAutomaticUpdates SUShowReleaseNotes; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$APP_DIR/Contents/Info.plist" >/dev/null 2>&1 || true
done

codesign_args=(--force --sign "$CODESIGN_IDENTITY" --entitlements "$ENTITLEMENTS_PATH")
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--timestamp)
fi

codesign "${codesign_args[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

printf 'Built MAS app candidate %s\n' "$APP_DIR"
