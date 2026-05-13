#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="${TOKEN_MONITOR_APP_INFO_PLIST:-$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist}"
REQUIRE_DIRECT_DMG_ACCESS="${TOKEN_MONITOR_REQUIRE_DIRECT_DMG_ACCESS:-0}"
REQUIRE_MAS_ACCESS="${TOKEN_MONITOR_REQUIRE_MAS_ACCESS:-0}"
missing_direct_gates=0
missing_mas_gates=0
failures=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-apple-access-handoff.sh [--require-direct-dmg-access] [--require-mas-access]

Checks the non-secret Apple access handoff inputs needed before Token Monitor
can move from repo preparation to real Apple signing, notarization, or Mac App
Store upload work.

This script does not create certificates, upload builds, notarize artifacts,
read secret values, or change App Store Connect state.

Options:
  --require-direct-dmg-access  Exit non-zero unless direct Developer ID access
                               gates are acknowledged.
  --require-mas-access         Exit non-zero unless Mac App Store access gates
                               are acknowledged.
  -h, --help                   Show this help.

Non-secret environment values:
  TOKEN_MONITOR_APPLE_TEAM_ID  Apple Developer Team ID.

Direct Developer ID DMG approval flags:
  TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY=1
  TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED=1
  TOKEN_MONITOR_DIRECT_DMG_APPROVED=1
  TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED=1
  TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED=1
  TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED=1

Mac App Store approval flags:
  TOKEN_MONITOR_MAS_TRACK_APPROVED=1
  TOKEN_MONITOR_APP_STORE_CONNECT_READY=1
  TOKEN_MONITOR_APP_STORE_CERTIFICATES_APPROVED=1
  TOKEN_MONITOR_APP_STORE_UPLOAD_AUTH_APPROVED=1
  TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED=1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-direct-dmg-access)
      REQUIRE_DIRECT_DMG_ACCESS=1
      shift
      ;;
    --require-mas-access)
      REQUIRE_MAS_ACCESS=1
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

pass() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

fail_later() {
  warn "$1"
  failures=$((failures + 1))
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

check_gate() {
  local variable="$1"
  local label="$2"
  local counter_name="$3"

  if [[ "${!variable:-}" == "1" ]]; then
    pass "$label"
  else
    warn "$label is not acknowledged ($variable=1)"
    case "$counter_name" in
      direct)
        missing_direct_gates=$((missing_direct_gates + 1))
        ;;
      mas)
        missing_mas_gates=$((missing_mas_gates + 1))
        ;;
      *)
        fail_later "Unknown gate counter: $counter_name"
        ;;
    esac
  fi
}

printf 'Token Monitor Apple access handoff readiness\n\n'
printf 'Info.plist: %s\n\n' "$INFO_PLIST"

if [[ ! -f "$INFO_PLIST" ]]; then
  printf '[FAIL] Info.plist not found: %s\n' "$INFO_PLIST" >&2
  exit 1
fi

app_name="$(plist_value CFBundleName)"
bundle_id="$(plist_value CFBundleIdentifier)"
version="$(plist_value CFBundleShortVersionString)"
build="$(plist_value CFBundleVersion)"

if [[ -n "$app_name" ]]; then
  pass "App name: $app_name"
else
  fail_later "App name is missing from Info.plist"
fi

if [[ -n "$bundle_id" ]]; then
  pass "Bundle ID: $bundle_id"
else
  fail_later "Bundle ID is missing from Info.plist"
fi

if [[ -n "$version" && -n "$build" ]]; then
  pass "App version/build: $version ($build)"
else
  fail_later "App version/build is missing from Info.plist"
fi

if [[ -n "${TOKEN_MONITOR_APPLE_TEAM_ID:-}" ]]; then
  if [[ "$TOKEN_MONITOR_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    pass "Apple Developer Team ID format is plausible"
  else
    fail_later "TOKEN_MONITOR_APPLE_TEAM_ID should look like 10 uppercase letters or digits"
  fi
else
  fail_later "TOKEN_MONITOR_APPLE_TEAM_ID is not set"
fi

printf '\nDirect Developer ID DMG access gates:\n'
check_gate TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY "Apple Developer Program membership is active" direct
check_gate TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED "Apple access model is approved without password sharing" direct
check_gate TOKEN_MONITOR_DIRECT_DMG_APPROVED "Direct Developer ID DMG path is approved" direct
check_gate TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED "Developer ID Application certificate creation/export is approved" direct
check_gate TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED "Notarization credentials are approved" direct
check_gate TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED "GitHub release secret setup is approved" direct

printf '\nMac App Store access gates:\n'
check_gate TOKEN_MONITOR_MAS_TRACK_APPROVED "Mac App Store track is approved" mas
check_gate TOKEN_MONITOR_APP_STORE_CONNECT_READY "App Store Connect app record, agreements, tax, and banking are ready" mas
check_gate TOKEN_MONITOR_APP_STORE_CERTIFICATES_APPROVED "Apple Distribution and installer certificates are approved" mas
check_gate TOKEN_MONITOR_APP_STORE_UPLOAD_AUTH_APPROVED "App Store upload authentication path is approved" mas
check_gate TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED "Reviewer plan and reviewer test access are approved" mas

printf '\nAccess handoff summary:\n'
printf -- '- Technical failures: %s\n' "$failures"
printf -- '- Missing direct DMG access gates: %s\n' "$missing_direct_gates"
printf -- '- Missing Mac App Store access gates: %s\n' "$missing_mas_gates"

if [[ "$failures" -gt 0 ]]; then
  if [[ "$REQUIRE_DIRECT_DMG_ACCESS" == "1" || "$REQUIRE_MAS_ACCESS" == "1" ]]; then
    printf '[FAIL] Apple access handoff has technical failures.\n' >&2
    exit 1
  fi
  warn "Apple access handoff has technical gaps"
fi

if [[ "$missing_direct_gates" -gt 0 && "$REQUIRE_DIRECT_DMG_ACCESS" == "1" ]]; then
  printf '[FAIL] Direct Developer ID DMG access handoff is incomplete.\n' >&2
  exit 1
fi

if [[ "$missing_mas_gates" -gt 0 && "$REQUIRE_MAS_ACCESS" == "1" ]]; then
  printf '[FAIL] Mac App Store access handoff is incomplete.\n' >&2
  exit 1
fi

if [[ "$missing_direct_gates" -gt 0 || "$missing_mas_gates" -gt 0 ]]; then
  warn "Apple access handoff is not fully acknowledged yet"
  printf '\nRun with --require-direct-dmg-access after Developer ID access is approved.\n'
  printf 'Run with --require-mas-access only if the Mac App Store track is approved.\n'
else
  pass "Apple access handoff gates are acknowledged"
fi
