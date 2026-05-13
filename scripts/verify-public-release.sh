#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_SLUG="${TOKEN_MONITOR_REPO_SLUG:-MediaPublishing/token-monitor}"
PAGES_BASE_URL="${TOKEN_MONITOR_PAGES_BASE_URL:-https://mediapublishing.github.io/token-monitor}"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
VERIFY_DMG_SIGNATURE="${TOKEN_MONITOR_VERIFY_DMG_SIGNATURE:-0}"
DOWNLOAD_DIR="${TOKEN_MONITOR_RELEASE_DOWNLOAD_DIR:-$ROOT_DIR/dist/public-release-verification}"

TAG="${1:-}"
VERSION="${2:-}"
BUILD_NUMBER="${3:-}"

pass() {
  printf '[OK] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

info() {
  printf '[INFO] %s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

check_url() {
  local label="$1"
  local url="$2"

  if curl -fsIL --retry 2 --retry-delay 1 "$url" >/dev/null; then
    pass "$label"
    info "$url"
  else
    fail "$label: $url"
  fi
}

check_command() {
  local label="$1"
  shift

  if output="$("$@" 2>&1)"; then
    pass "$label"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" | sed 's/^/  /'
    fi
  else
    fail "$label
$output"
  fi
}

require_command curl

if [[ -z "$VERSION" && -d "$APP_DIR" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || true)"
fi

if [[ -z "$BUILD_NUMBER" && -d "$APP_DIR" ]]; then
  BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist" 2>/dev/null || true)"
fi

if [[ -z "$TAG" && -n "$VERSION" ]]; then
  TAG="v$VERSION"
fi

if [[ -z "$TAG" || -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  cat >&2 <<'EOF'
Usage:
  ./scripts/verify-public-release.sh <tag> <version> <build>

Example:
  ./scripts/verify-public-release.sh v1.0.14 1.0.14 15

If dist/TokenMonitor.app exists, version and build default to its Info.plist.

Optional signed-release verification:
  TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 ./scripts/verify-public-release.sh <tag> <version> <build>

This downloads and verifies the public DMG, GitHub ZIP, and Sparkle update ZIP.
EOF
  exit 1
fi

RELEASE_BASE_URL="https://github.com/$REPO_SLUG/releases"
RELEASE_TAG_URL="$RELEASE_BASE_URL/tag/$TAG"
RELEASE_DOWNLOAD_URL="$RELEASE_BASE_URL/download/$TAG"
DMG_URL="$RELEASE_DOWNLOAD_URL/TokenMonitor-macOS.dmg"
ZIP_URL="$RELEASE_DOWNLOAD_URL/TokenMonitor-macOS.zip"
LANDING_URL="$PAGES_BASE_URL/"
APPCAST_URL="$PAGES_BASE_URL/appcast.xml"
UPDATE_ZIP_NAME="TokenMonitor-${VERSION}-${BUILD_NUMBER}-macOS.zip"
UPDATE_ZIP_URL="$PAGES_BASE_URL/updates/$UPDATE_ZIP_NAME"

printf 'Token Monitor public release verification\n'
printf 'Repository: %s\n' "$REPO_SLUG"
printf 'Tag: %s\n' "$TAG"
printf 'Version: %s\n' "$VERSION"
printf 'Build: %s\n\n' "$BUILD_NUMBER"

check_url "GitHub release page is reachable" "$RELEASE_TAG_URL"
check_url "GitHub DMG asset is reachable" "$DMG_URL"
check_url "GitHub ZIP asset is reachable" "$ZIP_URL"
check_url "GitHub Pages landing page is reachable" "$LANDING_URL"
check_url "Sparkle appcast is reachable" "$APPCAST_URL"
check_url "Sparkle update ZIP is reachable" "$UPDATE_ZIP_URL"

appcast="$(curl -fsSL --retry 2 --retry-delay 1 "$APPCAST_URL")"
if printf '%s' "$appcast" | grep -Fq "$UPDATE_ZIP_NAME"; then
  pass "Appcast references $UPDATE_ZIP_NAME"
else
  fail "Appcast does not reference $UPDATE_ZIP_NAME"
fi

if [[ "$VERIFY_DMG_SIGNATURE" == "1" ]]; then
  require_command codesign
  require_command ditto
  require_command spctl
  require_command xcrun

  release_download_dir="$DOWNLOAD_DIR/$TAG"
  downloaded_dmg="$release_download_dir/TokenMonitor-macOS.dmg"
  downloaded_zip="$release_download_dir/TokenMonitor-macOS.zip"
  downloaded_update_zip="$release_download_dir/$UPDATE_ZIP_NAME"
  zip_extract_dir="$release_download_dir/release-zip"
  update_extract_dir="$release_download_dir/update-zip"
  mkdir -p "$release_download_dir"
  rm -rf "$zip_extract_dir" "$update_extract_dir"

  info "Downloading DMG for local signature verification"
  info "$downloaded_dmg"
  curl -fL --retry 2 --retry-delay 1 "$DMG_URL" -o "$downloaded_dmg"

  check_command \
    "Downloaded DMG passes Gatekeeper signature assessment" \
    spctl --assess --type open --context context:primary-signature --verbose=4 "$downloaded_dmg"

  check_command \
    "Downloaded DMG has a stapled notarization ticket" \
    xcrun stapler validate "$downloaded_dmg"

  verify_downloaded_zip() {
    local label="$1"
    local zip_url="$2"
    local zip_path="$3"
    local extract_dir="$4"

    info "Downloading $label for local signature verification"
    info "$zip_path"
    curl -fL --retry 2 --retry-delay 1 "$zip_url" -o "$zip_path"

    mkdir -p "$extract_dir"
    ditto -x -k "$zip_path" "$extract_dir"

    local extracted_app="$extract_dir/TokenMonitor.app"
    if [[ ! -d "$extracted_app" ]]; then
      fail "Downloaded $label did not contain TokenMonitor.app: $zip_path"
    fi

    check_command \
      "Downloaded $label app code signature verifies" \
      codesign --verify --deep --strict "$extracted_app"

    local extracted_version
    local extracted_build
    extracted_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$extracted_app/Contents/Info.plist")"
    extracted_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$extracted_app/Contents/Info.plist")"
    if [[ "$extracted_version" == "$VERSION" && "$extracted_build" == "$BUILD_NUMBER" ]]; then
      pass "Downloaded $label app version matches $VERSION ($BUILD_NUMBER)"
    else
      fail "Downloaded $label app version mismatch: expected $VERSION ($BUILD_NUMBER), found $extracted_version ($extracted_build)"
    fi
  }

  verify_downloaded_zip "GitHub ZIP" "$ZIP_URL" "$downloaded_zip" "$zip_extract_dir"
  verify_downloaded_zip "Sparkle update ZIP" "$UPDATE_ZIP_URL" "$downloaded_update_zip" "$update_extract_dir"

else
  info "Set TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 to download the DMG, GitHub ZIP, and Sparkle update ZIP for local signature verification."
fi

printf '\nPublic release verification complete.\n'
