#!/usr/bin/env bash
set -euo pipefail

REPO="${TOKEN_MONITOR_GITHUB_REPO:-${GITHUB_REPOSITORY:-MediaPublishing/token-monitor}}"
REQUIRE_PRIVATE_REPORTING="${TOKEN_MONITOR_REQUIRE_PRIVATE_VULNERABILITY_REPORTING:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/check-github-security-reporting.sh [--require-private-vulnerability-reporting]

Checks GitHub repository security-reporting settings that support safe public
distribution and private vulnerability reports.

Options:
  --require-private-vulnerability-reporting  Exit non-zero unless GitHub private
                                             vulnerability reporting is enabled.
  -h, --help                                 Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-private-vulnerability-reporting)
      REQUIRE_PRIVATE_REPORTING=1
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

printf 'Token Monitor GitHub security reporting check\n'
printf 'Repository: %s\n\n' "$REPO"

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI is not installed"
fi

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is not installed"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI is not authenticated"
fi

repo_info="$(gh repo view "$REPO" --json hasIssuesEnabled,visibility,url)"
visibility="$(printf '%s\n' "$repo_info" | jq -r '.visibility')"
has_issues="$(printf '%s\n' "$repo_info" | jq -r '.hasIssuesEnabled')"

if [[ "$visibility" == "PUBLIC" ]]; then
  pass "Repository is public"
else
  warn "Repository visibility is $visibility"
fi

if [[ "$has_issues" == "true" ]]; then
  pass "GitHub Issues are enabled for public sanitized bug reports"
else
  warn "GitHub Issues are disabled; public support issue forms will not work"
fi

private_reporting_enabled="$(
  gh api -X GET "repos/$REPO/private-vulnerability-reporting" --jq '.enabled'
)"

if [[ "$private_reporting_enabled" == "true" ]]; then
  pass "Private vulnerability reporting is enabled"
else
  if [[ "$REQUIRE_PRIVATE_REPORTING" == "1" ]]; then
    fail "Private vulnerability reporting is not enabled"
  fi

  warn "Private vulnerability reporting is not enabled"
  printf '\nEnable it before broad public distribution so sensitive security reports do not need public issues.\n'
fi

printf '\nGitHub security reporting summary:\n'
printf -- '- Private vulnerability reporting enabled: %s\n' "$private_reporting_enabled"
