#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
build_args=(-c "$CONFIGURATION")
if [[ -n "${TOKEN_MONITOR_BUILD_SDK:-}" ]]; then
  [[ -d "$TOKEN_MONITOR_BUILD_SDK" ]] || { printf 'Build SDK not found.\n' >&2; exit 1; }
  build_args+=(--sdk "$TOKEN_MONITOR_BUILD_SDK" --build-system native)
fi
BUILD_DIR="$(cd "$ROOT_DIR" && swift build "${build_args[@]}" --show-bin-path)"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
SPARKLE_FRAMEWORK_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
CODESIGN_IDENTITY="${TOKEN_MONITOR_CODESIGN_IDENTITY:--}"

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

codesign "${codesign_args[@]}" "$FRAMEWORKS_DIR/Sparkle.framework" >/dev/null
codesign "${codesign_args[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

printf 'Built %s\n' "$APP_DIR"
