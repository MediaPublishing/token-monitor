#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${TOKEN_MONITOR_GITHUB_REPO:-${GITHUB_REPOSITORY:-MediaPublishing/token-monitor}}"
REQUIRED_LABELS=(
  "parser"
  "install"
  "needs-triage"
)

usage() {
  cat <<'EOF'
Usage: ./scripts/check-github-issue-labels.sh

Checks that GitHub issue labels referenced by the public issue templates exist
in the repository.

Environment:
  TOKEN_MONITOR_GITHUB_REPO  Override the GitHub repository.

Options:
  -h, --help                 Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

fail_check() {
  printf '[FAIL] %s\n' "$1"
  failure_count=$((failure_count + 1))
}

printf 'Token Monitor GitHub issue label check\n'
printf 'Repository: %s\n\n' "$REPO"

if ! command -v gh >/dev/null 2>&1; then
  printf '[FAIL] gh CLI is not installed\n' >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  printf '[FAIL] gh CLI is not authenticated\n' >&2
  exit 1
fi

if [[ ! -f "$ROOT_DIR/.github/ISSUE_TEMPLATE/parser-layout-bug.yml" ]]; then
  printf '[FAIL] parser-layout issue template is missing\n' >&2
  exit 1
fi

if [[ ! -f "$ROOT_DIR/.github/ISSUE_TEMPLATE/install-update-bug.yml" ]]; then
  printf '[FAIL] install/update issue template is missing\n' >&2
  exit 1
fi

failure_count=0
label_names="$(gh label list --repo "$REPO" --limit 200 | awk -F $'\t' '{print $1}')"

for label in "${REQUIRED_LABELS[@]}"; do
  if printf '%s\n' "$label_names" | grep -Fxq "$label"; then
    pass "GitHub label exists: $label"
  else
    fail_check "Missing GitHub label: $label"
  fi
done

for label in "${REQUIRED_LABELS[@]}"; do
  if grep -R -Fq -- "- $label" "$ROOT_DIR/.github/ISSUE_TEMPLATE"; then
    pass "Issue templates reference label: $label"
  else
    fail_check "Issue templates do not reference label: $label"
  fi
done

printf '\nGitHub issue label summary:\n'
printf -- '- Failure count: %s\n' "$failure_count"

if [[ "$failure_count" -gt 0 ]]; then
  exit 1
fi
