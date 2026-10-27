#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="${TOKEN_MONITOR_QA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
WORK="$ROOT/.build/session-recovery-proof"
CORE="$WORK/core"
APP="$WORK/SessionRecoveryProof.app"
mkdir -p "$CORE" "$APP/Contents/MacOS"
swiftc -swift-version 6 -sdk "$SDK" -emit-library -emit-module -module-name TokenMonitorCore \
  Sources/TokenMonitorCore/*.swift -emit-module-path "$CORE/TokenMonitorCore.swiftmodule" -o "$CORE/libTokenMonitorCore.dylib"
swiftc -swift-version 6 -sdk "$SDK" -parse-as-library -I "$CORE" -L "$CORE" -lTokenMonitorCore \
  -Xlinker -rpath -Xlinker "$CORE" Sources/TokenMonitorApp/DiagnosticsStore.swift \
  Sources/TokenMonitorApp/ServiceLoginWindowController.swift Sources/TokenMonitorApp/ServiceSessionController.swift \
  scripts/check-session-recovery.swift -o "$APP/Contents/MacOS/SessionRecoveryProof"
cp Sources/TokenMonitorApp/Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.mediapublishing.tokenmonitor.session-recovery-proof' \
  -c 'Set :CFBundleExecutable SessionRecoveryProof' -c 'Set :CFBundleName Session Recovery Proof' "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
PORT_FILE="$(mktemp "$WORK/server-port.XXXXXX")"
node scripts/session-recovery-fixtures.mjs > "$PORT_FILE" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
for _ in {1..100}; do
  [[ -s "$PORT_FILE" ]] && break
  sleep 0.1
done
PORT="$(head -n 1 "$PORT_FILE")"
[[ "$PORT" =~ ^[0-9]+$ ]]
"$APP/Contents/MacOS/SessionRecoveryProof" "http://127.0.0.1:$PORT" "$WORK/output"
