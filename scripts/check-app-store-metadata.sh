#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKET_PATH="${TOKEN_MONITOR_APP_STORE_PACKET:-$ROOT_DIR/docs/app-store-submission-packet.md}"
failure_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-app-store-metadata.sh

Validates draft App Store metadata limits from docs/app-store-submission-packet.md.
This does not submit or change App Store Connect metadata.

Optional environment:
  TOKEN_MONITOR_APP_STORE_PACKET  Override the submission packet path.
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

char_count() {
  local value="$1"
  printf '%s' "$value" | awk '{ total += length($0) } END { print total + 0 }'
}

byte_count() {
  local value="$1"
  printf '%s' "$value" | wc -c | tr -d ' '
}

check_char_range() {
  local label="$1"
  local value="$2"
  local min="$3"
  local max="$4"
  local length
  length="$(char_count "$value")"

  if [[ "$length" -lt "$min" || "$length" -gt "$max" ]]; then
    fail_check "$label length is $length characters; expected $min-$max"
  else
    pass "$label length is $length characters"
  fi
}

check_char_max() {
  local label="$1"
  local value="$2"
  local max="$3"
  local length
  length="$(char_count "$value")"

  if [[ "$length" -gt "$max" ]]; then
    fail_check "$label length is $length characters; maximum is $max"
  else
    pass "$label length is $length characters"
  fi
}

check_keywords() {
  local keywords="$1"
  local bytes
  local keyword
  local trimmed
  bytes="$(byte_count "$keywords")"

  if [[ "$bytes" -gt 100 ]]; then
    fail_check "Keywords are $bytes bytes; maximum is 100"
  else
    pass "Keywords are $bytes bytes"
  fi

  IFS=',' read -ra keyword_parts <<< "$keywords"
  for keyword in "${keyword_parts[@]}"; do
    trimmed="$(printf '%s' "$keyword" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$trimmed" ]]; then
      fail_check "Keyword list contains an empty keyword"
      continue
    fi

    if [[ "$(char_count "$trimmed")" -le 2 ]]; then
      fail_check "Keyword '$trimmed' is not longer than two characters"
    fi
  done
}

printf 'Token Monitor App Store metadata check\n'
printf 'Submission packet: %s\n\n' "$PACKET_PATH"

if [[ ! -f "$PACKET_PATH" ]]; then
  printf '[FAIL] Submission packet is missing: %s\n' "$PACKET_PATH" >&2
  exit 1
fi

app_name="$(extract_text_block_after_label "App name:")"
subtitle="$(extract_text_block_after_label "Subtitle:")"
promotional_text="$(extract_text_block_after_label "Promotional text:")"
description="$(extract_text_block_after_label "Description:")"
keywords="$(extract_text_block_after_label "Keywords:")"
support_url="$(extract_text_block_after_label "Support URL:")"
marketing_url="$(extract_text_block_after_label "Marketing URL:")"
privacy_url="$(extract_text_block_after_label "Privacy URL:")"

check_char_range "App name" "$app_name" 2 30
check_char_max "Subtitle" "$subtitle" 30
check_char_max "Promotional text" "$promotional_text" 170
check_char_max "Description" "$description" 4000
check_keywords "$keywords"

for url_label in "Support URL:$support_url" "Marketing URL:$marketing_url" "Privacy URL:$privacy_url"; do
  label="${url_label%%:*}"
  url="${url_label#*:}"
  if [[ "$url" == https://* ]]; then
    pass "$label uses HTTPS"
  else
    fail_check "$label must be an HTTPS URL"
  fi
done

printf '\nMetadata summary:\n'
printf -- '- Failure count: %s\n' "$failure_count"

if [[ "$failure_count" -gt 0 ]]; then
  exit 1
fi
