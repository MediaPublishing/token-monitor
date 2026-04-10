#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/TokenMonitor.app"
ZIP_PATH="$ROOT_DIR/dist/TokenMonitor-macOS.zip"

"$ROOT_DIR/scripts/build-app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

shasum -a 256 "$ZIP_PATH"
printf 'Packaged %s\n' "$ZIP_PATH"
