#!/usr/bin/env bash
set -euo pipefail

REPO="${TOKEN_MONITOR_GITHUB_REPO:-${GITHUB_REPOSITORY:-MediaPublishing/token-monitor}}"
PUBLIC_RELEASE_TAG="${TOKEN_MONITOR_PUBLIC_RELEASE_TAG:-v1.0.21}"
ALLOW_STABLE_RELEASES="${TOKEN_MONITOR_ALLOW_STABLE_RELEASES:-0}"
failure_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-github-release-channel.sh

Checks the public GitHub release channel policy.

Before Developer ID signing and notarization are available, public Token Monitor
builds must be GitHub prereleases so GitHub does not advertise an unsigned DMG
as the stable latest release.

Optional environment:
  TOKEN_MONITOR_GITHUB_REPO             Override the GitHub repository.
  TOKEN_MONITOR_PUBLIC_RELEASE_TAG      Public release tag expected by docs/site.
  TOKEN_MONITOR_ALLOW_STABLE_RELEASES=1 Allow stable releases after Developer ID
                                        signing and notarization are configured.
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

pass() {
  printf '[OK] %s\n' "$1"
}

fail_check() {
  failure_count=$((failure_count + 1))
  printf '[FAIL] %s\n' "$1"
}

printf 'Token Monitor GitHub release channel check\n'
printf 'Repository: %s\n' "$REPO"
printf 'Public release tag: %s\n\n' "$PUBLIC_RELEASE_TAG"

if ! command -v gh >/dev/null 2>&1; then
  printf '[FAIL] Missing required command: gh\n' >&2
  exit 1
fi

public_release_state="$(gh release view "$PUBLIC_RELEASE_TAG" \
  --repo "$REPO" \
  --json tagName,isDraft,isPrerelease \
  --jq '[.tagName, (.isDraft|tostring), (.isPrerelease|tostring)] | @tsv')"

IFS=$'\t' read -r tag_name is_draft is_prerelease <<< "$public_release_state"

if [[ "$tag_name" == "$PUBLIC_RELEASE_TAG" ]]; then
  pass "Configured public release exists"
else
  fail_check "Configured public release was not found: $PUBLIC_RELEASE_TAG"
fi

if [[ "$is_draft" == "false" ]]; then
  pass "Configured public release is published"
else
  fail_check "Configured public release is still a draft: $PUBLIC_RELEASE_TAG"
fi

if [[ "$is_prerelease" == "true" ]]; then
  pass "Configured public release is marked as prerelease"
elif [[ "$ALLOW_STABLE_RELEASES" == "1" ]]; then
  pass "Configured public release is stable and stable releases are allowed"
else
  fail_check "Configured public release must be a prerelease until Developer ID signing is available: $PUBLIC_RELEASE_TAG"
fi

stable_count="$(gh release list \
  --repo "$REPO" \
  --exclude-drafts \
  --exclude-pre-releases \
  --limit 100 \
  --json tagName \
  --jq 'length')"

if [[ "$stable_count" == "0" ]]; then
  pass "No stable GitHub releases are published"
elif [[ "$ALLOW_STABLE_RELEASES" == "1" ]]; then
  pass "Stable GitHub releases are present and allowed"
else
  fail_check "Stable GitHub releases are present before Developer ID signing is available"
  gh release list \
    --repo "$REPO" \
    --exclude-drafts \
    --exclude-pre-releases \
    --limit 100 \
    --json tagName,name,isLatest,publishedAt \
    --template '{{range .}}{{.tagName}}{{"\t"}}latest={{.isLatest}}{{"\t"}}{{.name}}{{"\n"}}{{end}}'
fi

printf '\nRelease channel summary:\n'
printf -- '- Failure count: %s\n' "$failure_count"

if [[ "$failure_count" -gt 0 ]]; then
  exit 1
fi
