#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="${TOKEN_MONITOR_QA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
if [[ ! -d "$SDK" ]]; then SDK="$(xcrun --show-sdk-path)"; fi
WORK="$ROOT/.build/menu-bar-proof"
CORE="$WORK/core"
APP="$WORK/MenuBarProof.app"
mkdir -p "$CORE" "$APP/Contents/MacOS"
swiftc -swift-version 6 -sdk "$SDK" -emit-library -emit-module -module-name TokenMonitorCore \
    Sources/TokenMonitorCore/*.swift -emit-module-path "$CORE/TokenMonitorCore.swiftmodule" -o "$CORE/libTokenMonitorCore.dylib"
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(
    rg --files Sources/TokenMonitorApp -g '*.swift' | rg -v 'TokenMonitorApplication.swift'
)
swiftc -swift-version 6 -D MAS_BUILD -sdk "$SDK" -parse-as-library -I "$CORE" -L "$CORE" -lTokenMonitorCore \
    -Xlinker -rpath -Xlinker "$CORE" "${sources[@]}" scripts/check-menu-bar-rendering.swift \
    -o "$APP/Contents/MacOS/MenuBarProof"
cp Sources/TokenMonitorApp/Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.mediapublishing.tokenmonitor.menu-bar-proof' \
    -c 'Set :CFBundleExecutable MenuBarProof' -c 'Set :CFBundleName Token Monitor Menu Bar Proof' "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/MenuBarProof" "$WORK/images"
