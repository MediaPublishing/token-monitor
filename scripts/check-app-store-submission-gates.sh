#!/usr/bin/env bash
set -euo pipefail

REQUIRE_HUMAN_GATES="${TOKEN_MONITOR_REQUIRE_APP_STORE_HUMAN_GATES:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/check-app-store-submission-gates.sh [--require-human-gates]

Checks the non-technical Mac App Store submission gates that cannot be proven
by codesign, tests, or static build verification.

Options:
  --require-human-gates  Exit non-zero unless every human/App Store Connect
                         gate below is acknowledged with an environment flag.
  -h, --help             Show this help.

Required environment flags in strict mode:
  TOKEN_MONITOR_APP_STORE_ACCOUNT_HOLDER_APPROVED=1
  TOKEN_MONITOR_APP_STORE_CONNECT_READY=1
  TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED=1
  TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED=1
  TOKEN_MONITOR_APP_STORE_SCREENSHOTS_APPROVED=1
  TOKEN_MONITOR_APP_STORE_SUPPORT_URL_APPROVED=1
  TOKEN_MONITOR_APP_STORE_SANDBOX_SMOKE_TEST_PASSED=1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-human-gates)
      REQUIRE_HUMAN_GATES=1
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

fail() {
  printf '[FAIL] %s\n' "$1"
  exit 1
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

printf 'Token Monitor Mac App Store submission gates\n\n'
printf 'This check covers human/App Store Connect gates only.\n'
printf 'Run ./scripts/preflight-mas-submission.sh for the technical MAS build gate.\n\n'

missing_gates=0
check_gate TOKEN_MONITOR_APP_STORE_ACCOUNT_HOLDER_APPROVED "Account Holder approved Mac App Store submission"
check_gate TOKEN_MONITOR_APP_STORE_CONNECT_READY "App Store Connect app record, agreements, tax, and banking are ready"
check_gate TOKEN_MONITOR_APP_STORE_PRIVACY_APPROVED "Privacy policy and App Store privacy labels are approved"
check_gate TOKEN_MONITOR_APP_STORE_REVIEWER_PLAN_APPROVED "Reviewer notes and reviewer test plan/accounts are approved"
check_gate TOKEN_MONITOR_APP_STORE_SCREENSHOTS_APPROVED "Screenshots are captured from the submitted binary and sanitized"
check_gate TOKEN_MONITOR_APP_STORE_SUPPORT_URL_APPROVED "Support URL and marketing URL are final"
check_gate TOKEN_MONITOR_APP_STORE_SANDBOX_SMOKE_TEST_PASSED "MAS sandbox smoke test passed"

printf '\nSubmission gates summary:\n'
printf -- '- Missing human/App Store Connect acknowledgements: %s\n' "$missing_gates"

if [[ "$missing_gates" -gt 0 ]]; then
  if [[ "$REQUIRE_HUMAN_GATES" == "1" ]]; then
    fail "Mac App Store human gates are incomplete"
  fi

  warn "Mac App Store submission is not ready yet"
  printf '\nRun ./scripts/check-app-store-submission-gates.sh --require-human-gates before upload.\n'
else
  pass "Mac App Store human gates are acknowledged"
fi
