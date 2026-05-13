#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/preflight-mas-submission.sh

Runs the technical Mac App Store submission preflight after Apple Distribution
signing is configured. This does not replace human App Store Connect, privacy,
reviewer-account, screenshot, or legal approval gates.

Run ./scripts/check-app-store-submission-gates.sh --require-human-gates before
upload to explicitly verify those non-technical gates.

Required:
  TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)"

EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  printf 'Unknown option: %s\n\n' "$1" >&2
  usage >&2
  exit 2
fi

run_step() {
  local title="$1"
  shift
  printf '\n==> %s\n' "$title"
  "$@"
}

cd "$ROOT_DIR"

printf 'Token Monitor Mac App Store submission preflight\n'
printf 'Repo: %s\n' "$ROOT_DIR"

if [[ -z "${TOKEN_MONITOR_MAS_CODESIGN_IDENTITY:-}" ]]; then
  cat >&2 <<'EOF'
Missing TOKEN_MONITOR_MAS_CODESIGN_IDENTITY.
Set it to the exact Apple Distribution identity before running this preflight.
EOF
  exit 1
fi

if [[ "$TOKEN_MONITOR_MAS_CODESIGN_IDENTITY" != Apple\ Distribution:* ]]; then
  cat >&2 <<EOF
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY must start with "Apple Distribution:".
Current value: $TOKEN_MONITOR_MAS_CODESIGN_IDENTITY
EOF
  exit 1
fi

run_step "Run Swift test suite" swift test
run_step "Check MAS static readiness" ./scripts/check-mas-readiness.sh
run_step "Build Apple Distribution signed MAS app" ./scripts/build-mas-app.sh
run_step "Verify submitted MAS app shape and Apple Distribution signature" \
  ./scripts/verify-mas-build.sh --require-apple-distribution

cat <<'EOF'

Technical MAS submission preflight complete.

Manual gates still required before App Store upload:
- Account Holder approval.
- App Store Connect app record, agreements, tax, and banking.
- Final privacy labels and privacy policy review.
- Reviewer test accounts or approved reviewer plan.
- Screenshots captured from the submitted MAS binary.
- Sandbox smoke test for login, refresh, snapshots, diagnostics, and Launch at Login.

Run ./scripts/check-app-store-submission-gates.sh --require-human-gates after
those approvals are complete.
EOF
