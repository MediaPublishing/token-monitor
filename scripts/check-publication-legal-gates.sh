#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_LEGAL_GATES="${TOKEN_MONITOR_REQUIRE_PUBLICATION_LEGAL_GATES:-0}"
missing_gates=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-publication-legal-gates.sh [--require-legal-gates]

Checks publication and legal approval gates that cannot be proven by tests,
codesign, notarization, or App Store Connect tooling.

This script does not choose a license, approve legal copy, or submit anything.

Options:
  --require-legal-gates  Exit non-zero unless every publication/legal gate is acknowledged.
  -h, --help             Show this help.

Required environment flags in strict mode:
  TOKEN_MONITOR_LICENSE_DECISION_APPROVED=1
  TOKEN_MONITOR_PUBLIC_CLAIMS_APPROVED=1
  TOKEN_MONITOR_SUPPORT_SECURITY_APPROVED=1
  TOKEN_MONITOR_PRIVACY_POLICY_APPROVED=1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-legal-gates)
      REQUIRE_LEGAL_GATES=1
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

printf 'Token Monitor publication/legal gates\n\n'
printf 'Checklist: %s\n\n' "$ROOT_DIR/docs/publication-legal-checklist.md"

if [[ -f "$ROOT_DIR/LICENSE" || -f "$ROOT_DIR/LICENSE.md" || -f "$ROOT_DIR/COPYING" ]]; then
  pass "Repository license file exists"
else
  warn "No repository license file exists; source-visible without a license must be an approved owner decision"
fi

check_gate TOKEN_MONITOR_LICENSE_DECISION_APPROVED "License or source-visible-without-license decision approved"
check_gate TOKEN_MONITOR_PUBLIC_CLAIMS_APPROVED "Public compatibility, privacy, notarization, and security claims approved"
check_gate TOKEN_MONITOR_SUPPORT_SECURITY_APPROVED "Support and security reporting routes approved"
check_gate TOKEN_MONITOR_PRIVACY_POLICY_APPROVED "Final privacy policy URL and language approved"

printf '\nPublication/legal gates summary:\n'
printf -- '- Missing publication/legal acknowledgements: %s\n' "$missing_gates"

if [[ "$missing_gates" -gt 0 ]]; then
  if [[ "$REQUIRE_LEGAL_GATES" == "1" ]]; then
    fail "Publication/legal gates are incomplete"
  fi

  warn "Publication/legal approval is not complete yet"
  printf '\nRun ./scripts/check-publication-legal-gates.sh --require-legal-gates before broad promotion or App Store submission.\n'
else
  pass "Publication/legal gates are acknowledged"
fi
