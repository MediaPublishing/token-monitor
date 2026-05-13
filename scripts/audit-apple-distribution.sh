#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${TOKEN_MONITOR_GITHUB_REPO:-${GITHUB_REPOSITORY:-MediaPublishing/token-monitor}}"
REQUIRE_COMPLETE=0
SKIP_NETWORK=0
RUN_TESTS=0
failure_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/audit-apple-distribution.sh [--require-complete] [--run-tests] [--skip-network]

Runs the Apple distribution completion audit without uploading, submitting,
publishing, signing, notarizing, or changing App Store Connect state.

Options:
  --require-complete  Use strict checks and exit non-zero while Apple distribution
                      blockers remain.
  --run-tests         Include swift test in the audit.
  --skip-network      Skip GitHub CLI checks that require network/auth.
  -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-complete)
      REQUIRE_COMPLETE=1
      shift
      ;;
    --run-tests)
      RUN_TESTS=1
      shift
      ;;
    --skip-network)
      SKIP_NETWORK=1
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
  if "$@"; then
    printf '[OK] %s\n' "$title"
  else
    local status=$?
    failure_count=$((failure_count + 1))
    printf '[WARN] %s exited with status %s\n' "$title" "$status"
  fi
}

run_required_step() {
  local title="$1"
  shift

  printf '\n==> %s\n' "$title"
  "$@"
  printf '[OK] %s\n' "$title"
}

check_worktree_status() {
  local status
  status="$(git status --short)"
  if [[ -n "$status" ]]; then
    printf '%s\n' "$status"
    return 1
  fi
}

cd "$ROOT_DIR"

printf 'Token Monitor Apple distribution audit\n'
printf 'Repo: %s\n' "$ROOT_DIR"
printf 'GitHub repository: %s\n' "$REPO"

run_step "Check worktree status" check_worktree_status
run_required_step "Check shell script syntax" bash -n scripts/*.sh
run_required_step "Check App Store metadata limits" ./scripts/check-app-store-metadata.sh

if [[ "$RUN_TESTS" == "1" ]]; then
  run_required_step "Run Swift test suite" swift test
else
  printf '\n[INFO] Swift tests skipped. Pass --run-tests to include them.\n'
fi

if [[ "$SKIP_NETWORK" == "0" ]]; then
  run_step "Check GitHub repository visibility" gh repo view "$REPO" --json visibility,url,defaultBranchRef
  run_step "Check latest main CI run" gh run list --repo "$REPO" --branch main --limit 1
else
  printf '\n[INFO] GitHub network/auth checks skipped.\n'
fi

if [[ "$REQUIRE_COMPLETE" == "1" ]]; then
  run_step "Check GitHub release secrets strictly" ./scripts/check-github-release-secrets.sh --require-signing-secrets
  run_step "Check local Apple distribution strictly" ./scripts/check-apple-distribution.sh --require-ready
  run_step "Check App Store screenshots strictly" ./scripts/check-app-store-screenshots.sh --require-ready
  run_step "Check MAS upload handoff strictly" ./scripts/check-app-store-upload-readiness.sh --require-ready
  run_step "Check App Store human gates strictly" ./scripts/check-app-store-submission-gates.sh --require-human-gates
else
  run_step "Check GitHub release secrets" ./scripts/check-github-release-secrets.sh
  run_step "Check local Apple distribution readiness" ./scripts/check-apple-distribution.sh
  run_step "Check App Store screenshots" ./scripts/check-app-store-screenshots.sh
  run_step "Check MAS upload handoff" ./scripts/check-app-store-upload-readiness.sh
  run_step "Check App Store human gates" ./scripts/check-app-store-submission-gates.sh
fi

printf '\nAudit summary:\n'
printf -- '- Command failure count: %s\n' "$failure_count"

if [[ "$REQUIRE_COMPLETE" == "1" ]]; then
  if [[ "$failure_count" -gt 0 ]]; then
    printf '[FAIL] Apple distribution is not complete yet.\n' >&2
    exit 1
  fi

  printf '[OK] Apple distribution completion checks passed.\n'
else
  printf '[INFO] Advisory audit complete. Use --require-complete after Apple credentials and approvals exist.\n'
fi
