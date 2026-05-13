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
RELEASE_NOTES_PATH="${TOKEN_MONITOR_RELEASE_NOTES_PATH:-}"
REQUIRE_DISTRIBUTION_READY="${TOKEN_MONITOR_REQUIRE_DISTRIBUTION_READY:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/package-release.sh [--require-distribution-ready]

Builds Token Monitor release artifacts: ZIP, DMG, Sparkle update ZIP, and appcast.

Options:
  --require-distribution-ready  Verify app and DMG with the strict Apple distribution check after packaging.
  -h, --help                    Show this help.

Environment:
  TOKEN_MONITOR_RELEASE_NOTES_PATH  Optional Markdown, HTML, or text release notes file for Sparkle.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-distribution-ready)
      REQUIRE_DISTRIBUTION_READY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

"$ROOT_DIR/scripts/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist")"
VERSIONED_ZIP_PATH="$UPDATES_DIR/TokenMonitor-${VERSION}-${BUILD_NUMBER}-macOS.zip"
VERSIONED_RELEASE_NOTES_PATH="${VERSIONED_ZIP_PATH%.zip}.md"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
TOKEN_MONITOR_SKIP_BUILD=1 "$ROOT_DIR/scripts/package-dmg.sh"

mkdir -p "$UPDATES_DIR"
cp "$ZIP_PATH" "$VERSIONED_ZIP_PATH"
if [[ -n "$RELEASE_NOTES_PATH" && -s "$RELEASE_NOTES_PATH" ]]; then
  cp "$RELEASE_NOTES_PATH" "$VERSIONED_RELEASE_NOTES_PATH"
else
  cat > "$VERSIONED_RELEASE_NOTES_PATH" <<EOF
# Token Monitor ${VERSION}

Token Monitor ${VERSION} build ${BUILD_NUMBER} is available.

See the GitHub Release page for the full changelog.
EOF
fi

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN_DIR/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --embed-release-notes \
    "$UPDATES_DIR"
elif [[ "${TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY:-}" == "1" ]]; then
  "$SPARKLE_BIN_DIR/generate_appcast" \
    --account token-monitor \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --embed-release-notes \
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

if [[ "$REQUIRE_DISTRIBUTION_READY" == "1" ]]; then
  verify_release_zip() {
    local label="$1"
    local zip_path="$2"
    local verify_dir="$3"

    rm -rf "$verify_dir"
    mkdir -p "$verify_dir"
    ditto -x -k "$zip_path" "$verify_dir"

    local extracted_app="$verify_dir/TokenMonitor.app"
    if [[ ! -d "$extracted_app" ]]; then
      printf '%s did not contain TokenMonitor.app: %s\n' "$label" "$zip_path" >&2
      exit 1
    fi

    codesign --verify --deep --strict "$extracted_app"

    local extracted_version
    local extracted_build
    extracted_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$extracted_app/Contents/Info.plist")"
    extracted_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$extracted_app/Contents/Info.plist")"
    if [[ "$extracted_version" != "$VERSION" || "$extracted_build" != "$BUILD_NUMBER" ]]; then
      printf '%s version mismatch: expected %s (%s), found %s (%s)\n' \
        "$label" "$VERSION" "$BUILD_NUMBER" "$extracted_version" "$extracted_build" >&2
      exit 1
    fi

    printf 'Verified %s %s contains signed TokenMonitor.app %s (%s)\n' \
      "$label" "$zip_path" "$extracted_version" "$extracted_build"
  }

  "$ROOT_DIR/scripts/check-apple-distribution.sh" --require-ready

  zip_verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/token-monitor-zip-verify.XXXXXX")"
  update_verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/token-monitor-update-verify.XXXXXX")"
  trap 'rm -rf "$zip_verify_dir" "$update_verify_dir"' EXIT

  verify_release_zip "GitHub release ZIP" "$ZIP_PATH" "$zip_verify_dir"
  verify_release_zip "Sparkle update ZIP" "$VERSIONED_ZIP_PATH" "$update_verify_dir"
fi

shasum -a 256 "$ZIP_PATH"
shasum -a 256 "$DMG_PATH"
shasum -a 256 "$VERSIONED_ZIP_PATH" "$APPCAST_PATH"
printf 'Packaged %s\n' "$ZIP_PATH"
printf 'Installer %s\n' "$DMG_PATH"
printf 'Update archive %s\n' "$VERSIONED_ZIP_PATH"
printf 'Appcast %s\n' "$APPCAST_PATH"
