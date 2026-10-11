#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="${TOKEN_MONITOR_QA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
if [[ ! -d "$SDK" ]]; then SDK="$(xcrun --show-sdk-path)"; fi
CORE="$ROOT/.build/analytics-qa-core"
APP="$ROOT/dist/AnalyticsQA.app"
SPARKLE="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
if [[ ! -d "$SPARKLE/Sparkle.framework" ]]; then
    printf 'Run swift build first to resolve Sparkle.\n' >&2
    exit 1
fi
mkdir -p "$CORE" "$APP/Contents/MacOS"
swiftc -swift-version 6 -sdk "$SDK" -emit-library -emit-module -module-name TokenMonitorCore \
    Sources/TokenMonitorCore/*.swift -emit-module-path "$CORE/TokenMonitorCore.swiftmodule" \
    -o "$CORE/libTokenMonitorCore.dylib"
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(
    rg --files Sources/TokenMonitorApp -g '*.swift' | rg -v 'TokenMonitorApplication.swift|AppDelegate.swift'
)
swiftc -swift-version 6 -sdk "$SDK" -parse-as-library -I "$CORE" -L "$CORE" -lTokenMonitorCore \
    -F "$SPARKLE" -framework Sparkle -Xlinker -rpath -Xlinker "$SPARKLE" \
    -Xlinker -rpath -Xlinker "$CORE" "${sources[@]}" scripts/analytics-qa.swift \
    -o "$APP/Contents/MacOS/AnalyticsQA"
cp Sources/TokenMonitorApp/Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.mediapublishing.tokenmonitor.analytics-qa' \
    -c 'Set :CFBundleExecutable AnalyticsQA' -c 'Set :CFBundleName Token Monitor Analytics QA' \
    -c 'Set :LSUIElement false' "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf 'Built synthetic QA app: %s\n' "$APP"
