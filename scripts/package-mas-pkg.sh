#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/mas/TokenMonitor.app"
PKG_PATH="$ROOT_DIR/dist/mas/TokenMonitor-macOS-AppStore.pkg"
INSTALLER_IDENTITY="${TOKEN_MONITOR_MAS_INSTALLER_IDENTITY:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/package-mas-pkg.sh

Builds a Mac App Store upload package from the Apple Distribution signed MAS app.

Required:
  TOKEN_MONITOR_MAS_CODESIGN_IDENTITY="Apple Distribution: <Name> (<TEAMID>)"
  TOKEN_MONITOR_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)"

Some teams may see the installer certificate listed as "Mac Installer Distribution".
This script accepts either installer identity prefix.

Optional:
  TOKEN_MONITOR_SKIP_MAS_BUILD=1  Reuse dist/mas/TokenMonitor.app instead of rebuilding it.
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

cd "$ROOT_DIR"

if [[ -z "${TOKEN_MONITOR_MAS_CODESIGN_IDENTITY:-}" ]]; then
  cat >&2 <<'EOF'
Missing TOKEN_MONITOR_MAS_CODESIGN_IDENTITY.
Set it to the exact Apple Distribution identity before packaging for App Store upload.
EOF
  exit 1
fi

if [[ "$TOKEN_MONITOR_MAS_CODESIGN_IDENTITY" != Apple\ Distribution:* ]]; then
  cat >&2 <<EOF
TOKEN_MONITOR_MAS_CODESIGN_IDENTITY must start with "Apple Distribution:".
Current value: $TOKEN_MONITOR_MAS_CODESIGN_IDENTITY
EOF
  exit 1
fi

if [[ -z "$INSTALLER_IDENTITY" ]]; then
  cat >&2 <<'EOF'
Missing TOKEN_MONITOR_MAS_INSTALLER_IDENTITY.
Set it to the Mac App Store installer signing identity before packaging, for example:
TOKEN_MONITOR_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: <Name> (<TEAMID>)"
EOF
  exit 1
fi

if [[ "$INSTALLER_IDENTITY" != 3rd\ Party\ Mac\ Developer\ Installer:* && "$INSTALLER_IDENTITY" != Mac\ Installer\ Distribution:* ]]; then
  cat >&2 <<EOF
TOKEN_MONITOR_MAS_INSTALLER_IDENTITY must start with "3rd Party Mac Developer Installer:" or "Mac Installer Distribution:".
Current value: $INSTALLER_IDENTITY
EOF
  exit 1
fi

if [[ "${TOKEN_MONITOR_SKIP_MAS_BUILD:-}" != "1" ]]; then
  "$ROOT_DIR/scripts/build-mas-app.sh"
fi

"$ROOT_DIR/scripts/verify-mas-build.sh" --require-apple-distribution "$APP_DIR"

mkdir -p "$(dirname "$PKG_PATH")"
rm -f "$PKG_PATH"

productbuild \
  --component "$APP_DIR" /Applications \
  --sign "$INSTALLER_IDENTITY" \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"

shasum -a 256 "$PKG_PATH"
printf 'Packaged MAS upload package %s\n' "$PKG_PATH"
