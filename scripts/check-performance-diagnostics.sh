#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${TOKEN_MONITOR_QA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
WORK="$ROOT/.build/performance-proof"
mkdir -p "$WORK/core"
cd "$ROOT"
swiftc -O -swift-version 6 -sdk "$SDK" -emit-library -emit-module -module-name TokenMonitorCore \
  Sources/TokenMonitorCore/*.swift -emit-module-path "$WORK/core/TokenMonitorCore.swiftmodule" -o "$WORK/core/libTokenMonitorCore.dylib"
swiftc -O -swift-version 6 -sdk "$SDK" -parse-as-library -I "$WORK/core" -L "$WORK/core" -lTokenMonitorCore \
  -Xlinker -rpath -Xlinker "$WORK/core" scripts/check-performance-diagnostics.swift -o "$WORK/PerformanceProof"
"$WORK/PerformanceProof" "${1:-$WORK/output}"
