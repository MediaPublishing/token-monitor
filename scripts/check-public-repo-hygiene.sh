#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
failure_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-public-repo-hygiene.sh

Checks tracked repository files for high-risk secret files and obvious secret
token patterns before public distribution.

This script is read-only. It does not inspect GitHub secret values, local
Keychain items, or ignored/untracked files.

Options:
  -h, --help  Show this help.
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

warn() {
  printf '[WARN] %s\n' "$1"
}

fail_item() {
  printf '[FAIL] %s\n' "$1"
  failure_count=$((failure_count + 1))
}

cd "$ROOT_DIR"

printf 'Token Monitor public repository hygiene check\n'
printf 'Repo: %s\n\n' "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail_item "Not inside a Git worktree"
else
  pass "Git worktree detected"
fi

sensitive_paths="$(
  git ls-files | grep -E '(^|/)(\.env|\.env\..+|id_rsa|id_dsa|id_ecdsa|id_ed25519|.*\.p12|.*\.pem|.*\.mobileprovision|.*\.provisionprofile|.*\.appstoreconnect/private_keys/.*|AuthKey_[A-Z0-9]+\.p8)$' || true
)"

if [[ -n "$sensitive_paths" ]]; then
  fail_item "Tracked sensitive file path(s) found"
  printf '%s\n' "$sensitive_paths" | sed 's/^/  /'
else
  pass "No tracked private key, provisioning, p12, p8, pem, or .env paths found"
fi

scan_pattern() {
  local label="$1"
  local pattern="$2"
  local matches
  local status

  set +e
  matches="$(git grep -n -I -E -e "$pattern" -- . ':!Package.resolved' 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail_item "$label pattern found in tracked text"
    printf '%s\n' "$matches" | sed 's/^/  /'
  elif [[ "$status" -eq 1 ]]; then
    pass "No $label pattern found"
  else
    fail_item "$label scan failed"
    printf '%s\n' "$matches" | sed 's/^/  /'
  fi
}

scan_pattern "private key block" '-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----'
scan_pattern "OpenAI secret key" 'sk-(proj-)?[A-Za-z0-9_-]{20,}'
scan_pattern "GitHub token" 'gh[pousr]_[A-Za-z0-9_]{30,}'
scan_pattern "Slack token" 'xox[baprs]-[A-Za-z0-9-]{20,}'
scan_pattern "AWS access key" 'AKIA[0-9A-Z]{16}'

printf '\nPublic repository hygiene summary:\n'
printf -- '- Failure count: %s\n' "$failure_count"

if [[ "$failure_count" -gt 0 ]]; then
  printf '[FAIL] Public repository hygiene check failed.\n' >&2
  exit 1
fi

printf '[OK] Public repository hygiene check passed.\n'
