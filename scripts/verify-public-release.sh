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
  require_command spctl
  require_command xcrun

  release_download_dir="$DOWNLOAD_DIR/$TAG"
  downloaded_dmg="$release_download_dir/TokenMonitor-macOS.dmg"
  mkdir -p "$release_download_dir"

  info "Downloading DMG for local signature verification"
  info "$downloaded_dmg"
  curl -fL --retry 2 --retry-delay 1 "$DMG_URL" -o "$downloaded_dmg"

  check_command \
    "Downloaded DMG passes Gatekeeper signature assessment" \
    spctl --assess --type open --context context:primary-signature --verbose=4 "$downloaded_dmg"

  check_command \
    "Downloaded DMG has a stapled notarization ticket" \
    xcrun stapler validate "$downloaded_dmg"
else
  info "Set TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1 to download the DMG and verify Gatekeeper/stapler status."
fi

printf '\nPublic release verification complete.\n'
