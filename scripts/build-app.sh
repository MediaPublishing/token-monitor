#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
build_args=(-c "$CONFIGURATION")
if [[ -n "${TOKEN_MONITOR_BUILD_SDK:-}" ]]; then
  [[ -d "$TOKEN_MONITOR_BUILD_SDK" ]] || { printf 'Build SDK not found.\n' >&2; exit 1; }
  build_args+=(--sdk "$TOKEN_MONITOR_BUILD_SDK" --build-system native)
fi
if [[ -n "${TOKEN_MONITOR_BUILD_JOBS:-}" ]]; then build_args+=(--jobs "$TOKEN_MONITOR_BUILD_JOBS"); fi
BUILD_DIR="$(cd "$ROOT_DIR" && swift build "${build_args[@]}" --show-bin-path)"
DIST_DIR="${TOKEN_MONITOR_DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/TokenMonitor.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
SPARKLE_FRAMEWORK_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
CODESIGN_IDENTITY="${TOKEN_MONITOR_CODESIGN_IDENTITY:--}"

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  python3 "$ROOT_DIR/scripts/apple-distribution.py" identity "$CODESIGN_IDENTITY"
fi

cd "$ROOT_DIR"

swift build "${build_args[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Sources/TokenMonitorApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
ditto "$ROOT_DIR/Sources/TokenMonitorApp/Resources/ProviderLogos" "$RESOURCES_DIR/ProviderLogos"
cp "$BUILD_DIR/TokenMonitorApp" "$MACOS_DIR/TokenMonitorApp"
ditto "$SPARKLE_FRAMEWORK_DIR" "$FRAMEWORKS_DIR/Sparkle.framework"
chmod +x "$MACOS_DIR/TokenMonitorApp"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/TokenMonitorApp" 2>/dev/null || true

codesign_args=(--force --sign "$CODESIGN_IDENTITY")
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--options runtime --timestamp)
fi

# Preserve Sparkle's helper entitlements; sign real nested bundles inside out.
sparkle_version="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"
for helper in "$sparkle_version"/XPCServices/*.xpc "$sparkle_version/Autoupdate" "$sparkle_version/Updater.app"; do
  codesign "${codesign_args[@]}" --preserve-metadata=entitlements "$helper" >/dev/null
done
codesign "${codesign_args[@]}" "$FRAMEWORKS_DIR/Sparkle.framework" >/dev/null
codesign "${codesign_args[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  python3 "$ROOT_DIR/scripts/apple-distribution.py" verify "$APP_DIR"
fi

printf 'Built %s\n' "$APP_DIR"
