#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="${TOKEN_MONITOR_APP_INFO_PLIST:-$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist}"
REQUIRE_READY="${TOKEN_MONITOR_REQUIRE_APP_STORE_IDENTITY_READY:-0}"
missing_gates=0
failures=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-app-store-identity.sh [--require-ready]

Checks the App Store Connect identity inputs that must match the submitted
macOS app record. This script does not create or edit anything in App Store
Connect.

Options:
  --require-ready  Exit non-zero unless identity fields and approvals are ready.
  -h, --help       Show this help.

Environment values checked by strict mode:
  TOKEN_MONITOR_APP_STORE_TEAM_ID         Apple Developer Team ID.
  TOKEN_MONITOR_APP_STORE_SKU             App Store Connect SKU.
  TOKEN_MONITOR_APP_INFO_PLIST            Override Info.plist path.

Required approval flags in strict mode:
  TOKEN_MONITOR_APP_STORE_TEAM_APPROVED=1
  TOKEN_MONITOR_APP_STORE_BUNDLE_ID_APPROVED=1
  TOKEN_MONITOR_APP_STORE_SKU_APPROVED=1
  TOKEN_MONITOR_APP_STORE_CATEGORY_APPROVED=1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-ready)
      REQUIRE_READY=1
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

check_required_value() {
  local value="$1"
  local label="$2"

  if [[ -n "$value" ]]; then
    pass "$label: $value"
  else
    fail_later "Missing $label"
  fi
}

check_gate() {
  local variable="$1"
  local label="$2"

  if [[ "${!variable:-}" == "1" ]]; then
    pass "$label"
  else
    warn "$label is not acknowledged ($variable=1)"
    missing_gates=$((missing_gates + 1))
  fi
}

printf 'Token Monitor App Store Connect identity readiness\n\n'
printf 'Info.plist: %s\n\n' "$INFO_PLIST"

if [[ ! -f "$INFO_PLIST" ]]; then
  printf '[FAIL] Info.plist not found: %s\n' "$INFO_PLIST" >&2
  exit 1
fi

app_name="$(plist_value CFBundleName)"
bundle_id="$(plist_value CFBundleIdentifier)"
category="$(plist_value LSApplicationCategoryType)"
minimum_system="$(plist_value LSMinimumSystemVersion)"
version="$(plist_value CFBundleShortVersionString)"
build="$(plist_value CFBundleVersion)"

check_required_value "$app_name" "App name"
check_required_value "$bundle_id" "Bundle ID"
check_required_value "$category" "App Store category"
check_required_value "$minimum_system" "Minimum macOS version"
check_required_value "$version" "Version"
check_required_value "$build" "Build number"

if [[ "$bundle_id" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ && "$bundle_id" == *.* ]]; then
  pass "Bundle ID format is plausible"
else
  fail_later "Bundle ID format is not plausible: $bundle_id"
fi

if [[ "$category" == public.app-category.* ]]; then
  pass "App Store category format is plausible"
else
  fail_later "App Store category should use public.app-category.*"
fi

if [[ -n "${TOKEN_MONITOR_APP_STORE_TEAM_ID:-}" ]]; then
  if [[ "$TOKEN_MONITOR_APP_STORE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    pass "Apple Developer Team ID format is plausible"
  else
    fail_later "Apple Developer Team ID should look like 10 uppercase letters or digits"
  fi
else
  fail_later "TOKEN_MONITOR_APP_STORE_TEAM_ID is not set"
fi

if [[ -n "${TOKEN_MONITOR_APP_STORE_SKU:-}" ]]; then
  if [[ "$TOKEN_MONITOR_APP_STORE_SKU" =~ ^[A-Za-z0-9._-]+$ ]]; then
    pass "App Store SKU format is plausible"
  else
    fail_later "App Store SKU should use letters, numbers, dots, underscores, or hyphens"
  fi
else
  fail_later "TOKEN_MONITOR_APP_STORE_SKU is not set"
fi

check_gate TOKEN_MONITOR_APP_STORE_TEAM_APPROVED "Apple Developer team approved for this app"
check_gate TOKEN_MONITOR_APP_STORE_BUNDLE_ID_APPROVED "Bundle ID approved for App Store Connect"
check_gate TOKEN_MONITOR_APP_STORE_SKU_APPROVED "App Store SKU approved"
check_gate TOKEN_MONITOR_APP_STORE_CATEGORY_APPROVED "App Store category approved"

printf '\nIdentity summary:\n'
printf -- '- Technical failures: %s\n' "$failures"
printf -- '- Missing identity approvals: %s\n' "$missing_gates"

if [[ "$failures" -gt 0 || "$missing_gates" -gt 0 ]]; then
  if [[ "$REQUIRE_READY" == "1" ]]; then
    printf '[FAIL] App Store Connect identity is not ready\n' >&2
    exit 1
  fi

  warn "App Store Connect identity is not fully approved yet"
  printf '\nRun ./scripts/check-app-store-identity.sh --require-ready before App Store Connect record creation or upload.\n'
else
  pass "App Store Connect identity is ready"
fi
