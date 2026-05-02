#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_SIGNING_SECRETS=0

usage() {
  cat <<'EOF'
Usage: ./scripts/preflight-release.sh [--require-signing-secrets]

Runs the local release readiness checks in the same order an operator should
use before publishing or republishing Token Monitor release assets.

Options:
  --require-signing-secrets  Fail if Developer ID GitHub secrets are missing.
  -h, --help                 Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-signing-secrets)
      REQUIRE_SIGNING_SECRETS=1
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

run_step() {
  local title="$1"
  shift
  printf '\n==> %s\n' "$title"
  "$@"
}

cd "$ROOT_DIR"

printf 'Token Monitor release preflight\n'
printf 'Repo: %s\n' "$ROOT_DIR"

run_step "Run Swift test suite" swift test
run_step "Build direct DMG app candidate" ./scripts/build-app.sh
run_step "Build MAS app candidate" ./scripts/build-mas-app.sh
run_step "Verify MAS app candidate" ./scripts/verify-mas-build.sh
run_step "Check MAS readiness" ./scripts/check-mas-readiness.sh

if [[ "$REQUIRE_SIGNING_SECRETS" == "1" ]]; then
  run_step "Check GitHub release secrets" env TOKEN_MONITOR_REQUIRE_SIGNING_SECRETS=1 ./scripts/check-github-release-secrets.sh
else
  run_step "Check GitHub release secrets" ./scripts/check-github-release-secrets.sh
fi

run_step "Check local Apple distribution readiness" ./scripts/check-apple-distribution.sh

printf '\nRelease preflight complete.\n'
