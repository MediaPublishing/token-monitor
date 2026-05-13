#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_READY="${TOKEN_MONITOR_REQUIRE_RELEASE_RECOVERY_READY:-0}"
failures=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-release-recovery-readiness.sh [--require-ready]

Checks that Token Monitor has a documented, non-destructive recovery path for a
bad public release or broken Sparkle update feed. This script does not modify
GitHub Releases, GitHub Pages, tags, or appcast files.

Options:
  --require-ready  Exit non-zero if recovery runbook coverage is incomplete.
  -h, --help       Show this help.
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
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" ]]; then
    pass "$label exists: ${path#$ROOT_DIR/}"
  else
    warn "$label is missing: ${path#$ROOT_DIR/}"
  fi
}

require_text() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    pass "$label"
  else
    warn "$label"
  fi
}

RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
VERIFY_SCRIPT="$ROOT_DIR/scripts/verify-public-release.sh"
RUNBOOK="$ROOT_DIR/docs/release-recovery-runbook.md"
COMPLETION_AUDIT="$ROOT_DIR/docs/apple-distribution-completion-audit.md"

printf 'Token Monitor release recovery readiness\n\n'

require_file "$RELEASE_WORKFLOW" "Release workflow"
require_file "$VERIFY_SCRIPT" "Public release verifier"
require_file "$RUNBOOK" "Release recovery runbook"

require_text "$RELEASE_WORKFLOW" "workflow_dispatch:" "Release workflow can be manually dispatched"
require_text "$RELEASE_WORKFLOW" "tag:" "Release workflow accepts an existing tag"
require_text "$RELEASE_WORKFLOW" "gh release upload" "Release workflow can replace release assets"
require_text "$RELEASE_WORKFLOW" "--clobber" "Release workflow replaces release assets explicitly"
require_text "$RELEASE_WORKFLOW" "deploy-pages" "Release workflow publishes GitHub Pages/appcast"

require_text "$VERIFY_SCRIPT" "TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1" "Verifier supports signed public asset checks"
require_text "$VERIFY_SCRIPT" "GitHub ZIP" "Verifier checks GitHub release ZIP"
require_text "$VERIFY_SCRIPT" "Sparkle update ZIP" "Verifier checks Sparkle update ZIP"

require_text "$RUNBOOK" "Hotfix Release" "Runbook documents hotfix release path"
require_text "$RUNBOOK" "Appcast Rollback" "Runbook documents appcast rollback path"
require_text "$RUNBOOK" "Do Not" "Runbook documents prohibited recovery actions"
require_text "$RUNBOOK" "TOKEN_MONITOR_VERIFY_DMG_SIGNATURE=1" "Runbook requires public signed asset verification"
require_text "$RUNBOOK" "GitHub Issues are public" "Runbook preserves support privacy warnings"
require_text "$RUNBOOK" "SPARKLE_PRIVATE_KEY" "Runbook covers Sparkle key exposure response"
require_text "$RUNBOOK" "Apple credentials" "Runbook covers Apple credential exposure response"

require_text "$COMPLETION_AUDIT" "docs/release-recovery-runbook.md" "Completion audit references release recovery runbook"

printf '\nRelease recovery summary:\n'
printf -- '- Missing recovery coverage items: %s\n' "$failures"

if [[ "$failures" -gt 0 ]]; then
  if [[ "$REQUIRE_READY" == "1" ]]; then
    printf '[FAIL] Release recovery readiness is incomplete\n' >&2
    exit 1
  fi

  printf '[WARN] Release recovery readiness is incomplete\n'
else
  pass "Release recovery readiness is documented"
fi
