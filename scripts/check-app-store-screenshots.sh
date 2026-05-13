#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_DIR="${TOKEN_MONITOR_APP_STORE_SCREENSHOT_DIR:-$ROOT_DIR/dist/app-store/screenshots}"
REQUIRE_READY="${TOKEN_MONITOR_REQUIRE_APP_STORE_SCREENSHOTS_READY:-0}"
warning_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-app-store-screenshots.sh [--require-ready]

Checks App Store screenshot file count, file type, and Mac screenshot dimensions.
This script cannot verify visual privacy; run the human screenshot review before upload.

Options:
  --require-ready  Exit non-zero if any screenshot readiness check warns.
  -h, --help       Show this help.

Optional environment:
  TOKEN_MONITOR_APP_STORE_SCREENSHOT_DIR  Override screenshot folder.
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
  warning_count=$((warning_count + 1))
  printf '[WARN] %s\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

is_allowed_size() {
  local width="$1"
  local height="$2"

  case "$width x $height" in
    "1280 x 800"|"1440 x 900"|"2560 x 1600"|"2880 x 1800")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

read_dimension() {
  local image_path="$1"
  local key="$2"

  sips -g "$key" "$image_path" 2>/dev/null | awk -v key="$key" '$1 == key":" { print $2; exit }'
}

printf 'Token Monitor App Store screenshot readiness\n'
printf 'Screenshot folder: %s\n\n' "$SCREENSHOT_DIR"

if ! command -v sips >/dev/null 2>&1; then
  warn "sips is not available; cannot inspect screenshot dimensions"
else
  pass "sips is available"
fi

if [[ ! -d "$SCREENSHOT_DIR" ]]; then
  warn "Screenshot folder is missing: $SCREENSHOT_DIR"
  info "Capture screenshots from the submitted MAS binary before App Store upload."
else
  pass "Screenshot folder exists"

  shopt -s nullglob
  screenshot_files=("$SCREENSHOT_DIR"/*)
  shopt -u nullglob
  screenshot_count="${#screenshot_files[@]}"

  if [[ "$screenshot_count" -ge 1 && "$screenshot_count" -le 10 ]]; then
    pass "Screenshot count is within App Store range: $screenshot_count"
  else
    warn "Screenshot count must be between 1 and 10; found $screenshot_count"
  fi

  for screenshot_path in "${screenshot_files[@]}"; do
    if [[ ! -f "$screenshot_path" ]]; then
      warn "Screenshot entry is not a file: $screenshot_path"
      continue
    fi

    filename="$(basename "$screenshot_path")"
    extension="${filename##*.}"
    extension="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"

    case "$extension" in
      png|jpg|jpeg)
        pass "$filename uses an accepted screenshot file extension"
        ;;
      *)
        warn "$filename must be .png, .jpg, or .jpeg"
        continue
        ;;
    esac

    width="$(read_dimension "$screenshot_path" pixelWidth || true)"
    height="$(read_dimension "$screenshot_path" pixelHeight || true)"

    if [[ -z "$width" || -z "$height" ]]; then
      warn "$filename dimensions could not be read"
      continue
    fi

    if is_allowed_size "$width" "$height"; then
      pass "$filename dimensions are accepted: ${width} x ${height}"
    else
      warn "$filename dimensions must be 1280 x 800, 1440 x 900, 2560 x 1600, or 2880 x 1800; found ${width} x ${height}"
    fi
  done
fi

cat <<'EOF'

Manual screenshot gate:
- Screenshots must come from the submitted MAS binary.
- Screenshots must contain no private account data, chat titles, tokens, cookies, or debug dumps.
- Account Holder or approved reviewer must approve the final screenshot set.
EOF

printf '\nScreenshot summary:\n'
printf -- '- Warning count: %s\n' "$warning_count"

if [[ "$REQUIRE_READY" == "1" ]]; then
  if [[ "$warning_count" -gt 0 ]]; then
    printf '\n[FAIL] App Store screenshots are not ready.\n' >&2
    exit 1
  fi

  printf '\n[OK] App Store screenshots are ready for human approval.\n'
fi
