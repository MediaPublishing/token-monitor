#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
DMG_PATH="$ROOT_DIR/dist/TokenMonitor-macOS.dmg"
NOTARY_PROFILE="${TOKEN_MONITOR_NOTARY_PROFILE:-}"

pass() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

print_command_result() {
  local label="$1"
  shift

  if output="$("$@" 2>&1)"; then
    pass "$label"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" | sed 's/^/  /'
    fi
  else
    warn "$label"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" | sed 's/^/  /'
    fi
  fi
}

printf 'Token Monitor Apple distribution readiness\n'
printf 'Repo: %s\n\n' "$ROOT_DIR"

if command -v xcrun >/dev/null 2>&1; then
  pass "xcrun is available"
  print_command_result "notarytool is available" xcrun --find notarytool
  print_command_result "stapler is available" xcrun --find stapler
else
  warn "xcrun is missing; install Xcode command line tools before signing or notarizing"
fi

if command -v security >/dev/null 2>&1; then
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  developer_id_identities="$(printf '%s\n' "$identities" | grep 'Developer ID Application' || true)"
  apple_distribution_identities="$(printf '%s\n' "$identities" | grep 'Apple Distribution' || true)"

  if [[ -n "$developer_id_identities" ]]; then
    pass "Developer ID Application signing identity found"
    printf '%s\n' "$developer_id_identities" | sed 's/^/  /'
  else
    warn "No Developer ID Application signing identity found in the current keychain"
  fi

  if [[ -n "$apple_distribution_identities" ]]; then
    pass "Apple Distribution signing identity found"
    printf '%s\n' "$apple_distribution_identities" | sed 's/^/  /'
  else
    info "No Apple Distribution identity found; only needed for a future Mac App Store track"
  fi
else
  warn "security command is missing; cannot inspect code-signing identities"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  print_command_result \
    "notarytool keychain profile '$NOTARY_PROFILE' can be used" \
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --limit 1
else
  warn "TOKEN_MONITOR_NOTARY_PROFILE is not set; notarization readiness was not checked"
fi

printf '\nBuild artifacts\n'

if [[ -d "$APP_DIR" ]]; then
  pass "App bundle exists: $APP_DIR"
  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || true)"
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist" 2>/dev/null || true)"
  if [[ -n "$version" && -n "$build" ]]; then
    info "App version: $version ($build)"
  fi

  print_command_result "App code signature verifies" codesign --verify --deep --strict "$APP_DIR"

  signature_details="$(codesign -dv --verbose=4 "$APP_DIR" 2>&1 || true)"
  signature_type="$(printf '%s\n' "$signature_details" | awk -F= '/Signature=/ {print $2; exit}')"
  team_identifier="$(printf '%s\n' "$signature_details" | awk -F= '/TeamIdentifier=/ {print $2; exit}')"

  if [[ -n "$signature_type" ]]; then
    info "App signature: $signature_type"
  fi
  if [[ -n "$team_identifier" && "$team_identifier" != "not set" ]]; then
    info "Team identifier: $team_identifier"
  else
    warn "No TeamIdentifier found; ad hoc builds are expected to fail Gatekeeper"
  fi

  print_command_result "Gatekeeper app bundle assessment" spctl --assess --type execute --verbose=4 "$APP_DIR"
else
  warn "App bundle missing: $APP_DIR"
  info "Run ./scripts/build-app.sh before this readiness check"
fi

if [[ -f "$DMG_PATH" ]]; then
  pass "DMG exists: $DMG_PATH"
  print_command_result \
    "Gatekeeper DMG signature assessment" \
    spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
  print_command_result "DMG stapled notarization ticket validates" xcrun stapler validate "$DMG_PATH"
else
  warn "DMG missing: $DMG_PATH"
  info "Run ./scripts/package-dmg.sh or ./scripts/package-release.sh before checking the installer"
fi

cat <<'EOF'

Developer ID release command once credentials exist:

TOKEN_MONITOR_CODESIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
TOKEN_MONITOR_NOTARIZE=1 \
TOKEN_MONITOR_NOTARY_PROFILE=token-monitor-notary \
TOKEN_MONITOR_USE_KEYCHAIN_SPARKLE_KEY=1 \
./scripts/package-release.sh
EOF
