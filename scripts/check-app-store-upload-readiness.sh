#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PKG_PATH="${TOKEN_MONITOR_MAS_PKG_PATH:-$ROOT_DIR/dist/mas/TokenMonitor-macOS-AppStore.pkg}"
REQUIRE_READY="${TOKEN_MONITOR_REQUIRE_APP_STORE_UPLOAD_READY:-0}"
warning_count=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-app-store-upload-readiness.sh [--require-ready]

Checks whether the Mac App Store upload handoff is ready after
scripts/preflight-mas-submission.sh has produced the upload package.

This script does not upload anything to App Store Connect.

Options:
  --require-ready  Exit non-zero if any upload readiness check warns.
  -h, --help       Show this help.

Optional environment:
  TOKEN_MONITOR_MAS_PKG_PATH                              Override the MAS pkg path.
  TOKEN_MONITOR_APP_STORE_CONNECT_API_KEY_ID              App Store Connect API key ID.
  TOKEN_MONITOR_APP_STORE_CONNECT_API_ISSUER_ID           App Store Connect issuer ID.
  TOKEN_MONITOR_APP_STORE_CONNECT_API_PRIVATE_KEY_PATH    Local path to the API private key.
  TOKEN_MONITOR_APP_STORE_USERNAME                        Apple ID for altool upload fallback.
  TOKEN_MONITOR_APP_STORE_APP_PASSWORD                    App-specific password for altool upload fallback.
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

has_altool=0
has_transporter=0

printf 'Token Monitor App Store upload readiness\n'
printf 'Repo: %s\n\n' "$ROOT_DIR"

if [[ -f "$PKG_PATH" ]]; then
  pass "MAS upload package exists: $PKG_PATH"
  if pkgutil --check-signature "$PKG_PATH" >/tmp/token-monitor-pkg-signature.out 2>&1; then
    pass "MAS upload package signature can be inspected"
    sed 's/^/  /' /tmp/token-monitor-pkg-signature.out
  else
    warn "MAS upload package signature could not be verified"
    sed 's/^/  /' /tmp/token-monitor-pkg-signature.out || true
  fi
else
  warn "MAS upload package is missing: $PKG_PATH"
  info "Run ./scripts/preflight-mas-submission.sh after Apple Distribution signing is configured."
fi

printf '\nUpload tools\n'

if xcrun --find altool >/tmp/token-monitor-altool-path.out 2>/dev/null; then
  has_altool=1
  pass "altool is available"
  sed 's/^/  /' /tmp/token-monitor-altool-path.out
else
  warn "altool is not available through xcrun; install full Xcode or use Transporter."
fi

transporter_paths=(
  "/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
  "/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Versions/A/itms/bin/iTMSTransporter"
)

for transporter_path in "${transporter_paths[@]}"; do
  if [[ -x "$transporter_path" ]]; then
    has_transporter=1
    pass "Transporter command-line tool is available: $transporter_path"
    break
  fi
done

if [[ "$has_transporter" == "0" ]]; then
  if command -v iTMSTransporter >/tmp/token-monitor-transporter-path.out 2>/dev/null; then
    has_transporter=1
    pass "Transporter command-line tool is available"
    sed 's/^/  /' /tmp/token-monitor-transporter-path.out
  else
    warn "Transporter command-line tool was not found."
    info "Install Apple's Transporter app or full Xcode before command-line upload."
  fi
fi

if [[ "$has_altool" == "0" && "$has_transporter" == "0" ]]; then
  warn "No App Store Connect upload tool is available on this machine."
fi

printf '\nUpload authentication\n'

api_key_ready=0
if [[ -n "${TOKEN_MONITOR_APP_STORE_CONNECT_API_KEY_ID:-}" &&
      -n "${TOKEN_MONITOR_APP_STORE_CONNECT_API_ISSUER_ID:-}" &&
      -n "${TOKEN_MONITOR_APP_STORE_CONNECT_API_PRIVATE_KEY_PATH:-}" ]]; then
  if [[ -f "$TOKEN_MONITOR_APP_STORE_CONNECT_API_PRIVATE_KEY_PATH" ]]; then
    api_key_ready=1
    pass "App Store Connect API key upload credentials are present"
  else
    warn "TOKEN_MONITOR_APP_STORE_CONNECT_API_PRIVATE_KEY_PATH does not point to an existing file"
  fi
else
  info "App Store Connect API key upload credentials are not fully configured"
fi

apple_id_ready=0
if [[ -n "${TOKEN_MONITOR_APP_STORE_USERNAME:-}" &&
      -n "${TOKEN_MONITOR_APP_STORE_APP_PASSWORD:-}" ]]; then
  apple_id_ready=1
  pass "Apple ID and app-specific password upload credentials are present"
else
  info "Apple ID app-specific password upload credentials are not fully configured"
fi

if [[ "$api_key_ready" == "0" && "$apple_id_ready" == "0" ]]; then
  warn "No App Store Connect upload authentication method is configured."
fi

cat <<'EOF'

Upload handoff:
- Use App Store Connect or Transporter only after Account Holder approval.
- Keep API private keys and app-specific passwords outside the repository.
- Run ./scripts/check-app-store-submission-gates.sh --require-human-gates before upload.
EOF

if [[ "$REQUIRE_READY" == "1" ]]; then
  if [[ "$warning_count" -gt 0 ]]; then
    printf '\n[FAIL] App Store upload readiness has %s warning(s).\n' "$warning_count" >&2
    exit 1
  fi

  printf '\n[OK] App Store upload readiness is strict-clean.\n'
fi
