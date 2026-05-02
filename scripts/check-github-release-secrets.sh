#!/usr/bin/env bash
set -euo pipefail

REPO="${TOKEN_MONITOR_GITHUB_REPO:-${GITHUB_REPOSITORY:-MediaPublishing/token-monitor}}"
REQUIRE_SIGNING_SECRETS="${TOKEN_MONITOR_REQUIRE_SIGNING_SECRETS:-0}"

required_preview_secrets=(
  SPARKLE_PRIVATE_KEY
)

required_signing_secrets=(
  TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_BASE64
  TOKEN_MONITOR_DEVELOPER_ID_CERTIFICATE_PASSWORD
  TOKEN_MONITOR_CODESIGN_IDENTITY
  TOKEN_MONITOR_NOTARY_APPLE_ID
  TOKEN_MONITOR_NOTARY_TEAM_ID
  TOKEN_MONITOR_NOTARY_APP_PASSWORD
)

optional_signing_secrets=(
  TOKEN_MONITOR_RELEASE_KEYCHAIN_PASSWORD
)

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

has_secret() {
  local name="$1"
  printf '%s\n' "$secret_names" | grep -Fxq "$name"
}

printf 'Token Monitor GitHub release secrets readiness\n'
printf 'Repository: %s\n\n' "$REPO"

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI is not installed"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI is not authenticated"
fi

secret_names="$(gh secret list --repo "$REPO" --app actions --json name --jq '.[].name')"

missing_preview=0
for secret in "${required_preview_secrets[@]}"; do
  if has_secret "$secret"; then
    pass "Required preview release secret exists: $secret"
  else
    warn "Missing required preview release secret: $secret"
    missing_preview=$((missing_preview + 1))
  fi
done

missing_signing=0
for secret in "${required_signing_secrets[@]}"; do
  if has_secret "$secret"; then
    pass "Required Developer ID release secret exists: $secret"
  else
    warn "Missing Developer ID release secret: $secret"
    missing_signing=$((missing_signing + 1))
  fi
done

for secret in "${optional_signing_secrets[@]}"; do
  if has_secret "$secret"; then
    pass "Optional release secret exists: $secret"
  else
    warn "Optional release secret is not set: $secret"
  fi
done

printf '\nRelease secrets summary:\n'
printf -- '- Missing preview release secrets: %s\n' "$missing_preview"
printf -- '- Missing Developer ID release secrets: %s\n' "$missing_signing"

if [[ "$missing_preview" -gt 0 ]]; then
  fail "Preview release secrets are incomplete"
fi

if [[ "$missing_signing" -gt 0 ]]; then
  if [[ "$REQUIRE_SIGNING_SECRETS" == "1" ]]; then
    fail "Developer ID release secrets are incomplete"
  fi

  warn "Developer ID signing/notarization is not ready yet"
  printf '\nSet TOKEN_MONITOR_REQUIRE_SIGNING_SECRETS=1 to fail when Developer ID secrets are missing.\n'
else
  pass "Developer ID signing/notarization secrets are present"
fi
