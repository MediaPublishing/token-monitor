#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR=""
REQUIRE_APPLE_DISTRIBUTION="${TOKEN_MONITOR_REQUIRE_APPLE_DISTRIBUTION:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify-mas-build.sh [--require-apple-distribution] [app_path]

Verifies a Mac App Store build candidate.

Options:
  --require-apple-distribution  Fail unless the app is signed with an Apple Distribution identity.
  -h, --help                    Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-apple-distribution)
      REQUIRE_APPLE_DISTRIBUTION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$APP_DIR" ]]; then
        APP_DIR="$1"
        shift
      else
        printf 'Unknown argument: %s\n\n' "$1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

APP_DIR="${APP_DIR:-$ROOT_DIR/dist/mas/TokenMonitor.app}"
EXECUTABLE="$APP_DIR/Contents/MacOS/TokenMonitorApp"
INFO_PLIST="$APP_DIR/Contents/Info.plist"

pass() {
  printf '[OK] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

printf 'Token Monitor MAS build verification\n'
printf 'App: %s\n\n' "$APP_DIR"

[[ -d "$APP_DIR" ]] || fail "MAS app bundle does not exist"
[[ -x "$EXECUTABLE" ]] || fail "MAS app executable is missing or not executable"
[[ -f "$INFO_PLIST" ]] || fail "MAS Info.plist is missing"
pass "MAS app bundle exists"

if find "$APP_DIR" -iname '*Sparkle*' -print -quit | grep -q .; then
  fail "MAS app bundle contains Sparkle files"
fi
pass "MAS app bundle does not contain Sparkle files"

if otool -L "$EXECUTABLE" | grep -Fq "Sparkle"; then
  fail "MAS app executable links Sparkle"
fi
pass "MAS app executable does not link Sparkle"

for key in SUFeedURL SUPublicEDKey SUEnableAutomaticChecks SUAllowsAutomaticUpdates SUShowReleaseNotes; do
  if /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" >/dev/null 2>&1; then
    fail "MAS Info.plist still contains $key"
  fi
done
pass "MAS Info.plist does not contain Sparkle update keys"

entitlements="$(codesign -d --entitlements - "$APP_DIR" 2>/dev/null || true)"
if ! grep -Fq "com.apple.security.app-sandbox" <<< "$entitlements"; then
  fail "MAS app is missing app sandbox entitlement"
fi
if ! grep -Fq "com.apple.security.network.client" <<< "$entitlements"; then
  fail "MAS app is missing network client entitlement"
fi
pass "MAS app has sandbox and network client entitlements"

codesign --verify --deep --strict "$APP_DIR" >/dev/null
pass "MAS app code signature verifies"

if [[ "$REQUIRE_APPLE_DISTRIBUTION" == "1" ]]; then
  signature_details="$(codesign -dv "$APP_DIR" 2>&1 || true)"
  if grep -Fq "Authority=Apple Distribution:" <<< "$signature_details"; then
    pass "MAS app is signed with an Apple Distribution identity"
  else
    fail "MAS app is not signed with an Apple Distribution identity"
  fi
fi

printf '\nMAS build verification complete.\n'
