#!/usr/bin/env bash
set -euo pipefail

REPO="${TOKEN_MONITOR_GITHUB_REPO:-${GITHUB_REPOSITORY:-MediaPublishing/token-monitor}}"
REQUIRE_DIRECT_DMG_VARIABLES="${TOKEN_MONITOR_REQUIRE_DIRECT_DMG_VARIABLES:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/check-github-release-variables.sh [--require-direct-dmg-variables]

Checks non-secret GitHub Actions repository variables used by the signed
Token Monitor release workflow.

Options:
  --require-direct-dmg-variables  Exit non-zero unless every direct Developer ID
                                  release variable is present and valid.
  -h, --help                      Show this help.

Required direct Developer ID release variables:
  TOKEN_MONITOR_APPLE_TEAM_ID
  TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY=1
  TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED=1
  TOKEN_MONITOR_DIRECT_DMG_APPROVED=1
  TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED=1
  TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED=1
  TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED=1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-direct-dmg-variables)
      REQUIRE_DIRECT_DMG_VARIABLES=1
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

required_flag_variables=(
  TOKEN_MONITOR_APPLE_DEVELOPER_PROGRAM_READY
  TOKEN_MONITOR_APPLE_ACCESS_MODEL_APPROVED
  TOKEN_MONITOR_DIRECT_DMG_APPROVED
  TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_APPROVED
  TOKEN_MONITOR_NOTARY_CREDENTIALS_APPROVED
  TOKEN_MONITOR_GITHUB_RELEASE_SECRETS_APPROVED
)

pass() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  exit 1
}

variable_value() {
  local name="$1"
  printf '%s\n' "$variables_json" | /usr/bin/python3 -c '
import json
import sys

target = sys.argv[1]
for item in json.load(sys.stdin):
    if item.get("name") == target:
        print(item.get("value") or "")
        break
' "$name"
}

printf 'Token Monitor GitHub release variable readiness\n'
printf 'Repository: %s\n\n' "$REPO"

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI is not installed"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI is not authenticated"
fi

variables_json="$(gh variable list --repo "$REPO" --json name,value)"
missing_or_invalid=0

team_id="$(variable_value TOKEN_MONITOR_APPLE_TEAM_ID)"
if [[ -n "$team_id" ]]; then
  if [[ "$team_id" =~ ^[A-Z0-9]{10}$ ]]; then
    pass "TOKEN_MONITOR_APPLE_TEAM_ID format is plausible"
  else
    warn "TOKEN_MONITOR_APPLE_TEAM_ID should look like 10 uppercase letters or digits"
    missing_or_invalid=$((missing_or_invalid + 1))
  fi
else
  warn "Missing GitHub repository variable: TOKEN_MONITOR_APPLE_TEAM_ID"
  missing_or_invalid=$((missing_or_invalid + 1))
fi

for variable in "${required_flag_variables[@]}"; do
  value="$(variable_value "$variable")"
  if [[ "$value" == "1" ]]; then
    pass "$variable is acknowledged"
  elif [[ -n "$value" ]]; then
    warn "$variable must be set to 1 for signed Developer ID releases"
    missing_or_invalid=$((missing_or_invalid + 1))
  else
    warn "Missing GitHub repository variable: $variable"
    missing_or_invalid=$((missing_or_invalid + 1))
  fi
done

printf '\nRelease variable summary:\n'
printf -- '- Missing or invalid direct DMG variables: %s\n' "$missing_or_invalid"

if [[ "$missing_or_invalid" -gt 0 ]]; then
  if [[ "$REQUIRE_DIRECT_DMG_VARIABLES" == "1" ]]; then
    fail "GitHub release variables are incomplete"
  fi

  warn "Signed Developer ID release variables are not ready yet"
  printf '\nRun ./scripts/check-github-release-variables.sh --require-direct-dmg-variables after Apple access is approved.\n'
else
  pass "GitHub release variables are ready for signed Developer ID releases"
fi
