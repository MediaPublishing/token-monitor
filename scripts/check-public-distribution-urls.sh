#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKET_PATH="${TOKEN_MONITOR_APP_STORE_PACKET:-$ROOT_DIR/docs/app-store-submission-packet.md}"
PUBLIC_RELEASE_TAG="${TOKEN_MONITOR_PUBLIC_RELEASE_TAG:-v1.0.25}"
failure_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-public-distribution-urls.sh

Checks public URLs used for App Store metadata and public distribution.
This script performs read-only network checks and does not publish, upload, or
change App Store Connect metadata.

Optional environment:
  TOKEN_MONITOR_APP_STORE_PACKET  Override the submission packet path.
  TOKEN_MONITOR_PUBLIC_RELEASE_TAG Override the public release tag to verify.
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

extract_text_block_after_label() {
  local label="$1"
  awk -v label="$label" '
    $0 == label { seen_label = 1; next }
    seen_label && /^```text$/ { in_block = 1; next }
    seen_label && in_block && /^```$/ { exit }
    seen_label && in_block { print }
  ' "$PACKET_PATH"
}

check_url() {
  local label="$1"
  local url="$2"

  if [[ -z "$url" ]]; then
    fail_check "$label is empty"
    return
  fi

  if [[ "$url" != https://* ]]; then
    fail_check "$label must use HTTPS: $url"
    return
  fi

  if curl -fsIL --retry 2 --retry-delay 1 "$url" >/dev/null; then
    pass "$label is reachable"
    printf '  %s\n' "$url"
  else
    fail_check "$label is not reachable: $url"
  fi
}

printf 'Token Monitor public distribution URL check\n'
printf 'Submission packet: %s\n\n' "$PACKET_PATH"
printf 'Public release tag: %s\n\n' "$PUBLIC_RELEASE_TAG"

if [[ ! -f "$PACKET_PATH" ]]; then
  printf '[FAIL] Submission packet is missing: %s\n' "$PACKET_PATH" >&2
  exit 1
fi

support_url="$(extract_text_block_after_label "Support URL:")"
marketing_url="$(extract_text_block_after_label "Marketing URL:")"
privacy_url="$(extract_text_block_after_label "Privacy URL:")"

check_url "Support URL" "$support_url"
check_url "Marketing URL" "$marketing_url"
check_url "Privacy URL" "$privacy_url"
check_url "Public release page" "https://github.com/MediaPublishing/token-monitor/releases/tag/$PUBLIC_RELEASE_TAG"
check_url "Public DMG download URL" "https://github.com/MediaPublishing/token-monitor/releases/download/$PUBLIC_RELEASE_TAG/TokenMonitor-macOS.dmg"
check_url "Security reporting URL" "https://github.com/MediaPublishing/token-monitor/security"

printf '\nPublic distribution URL summary:\n'
printf -- '- Failure count: %s\n' "$failure_count"

if [[ "$failure_count" -gt 0 ]]; then
  exit 1
fi
