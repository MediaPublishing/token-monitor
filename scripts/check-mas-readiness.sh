#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENTITLEMENTS_PATH="$ROOT_DIR/packaging/TokenMonitorMAS.entitlements"
MAS_BUILD_SCRIPT="$ROOT_DIR/scripts/build-mas-app.sh"

pass() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

has_text() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] && grep -Fq "$pattern" "$file"
}

blockers=0

printf 'Token Monitor Mac App Store readiness\n'
printf 'Repo: %s\n\n' "$ROOT_DIR"

if [[ -f "$ENTITLEMENTS_PATH" ]]; then
  pass "Draft MAS entitlements exist: packaging/TokenMonitorMAS.entitlements"
  if has_text "$ENTITLEMENTS_PATH" "com.apple.security.app-sandbox"; then
    pass "App Sandbox entitlement is present"
  else
    warn "Missing com.apple.security.app-sandbox"
    blockers=$((blockers + 1))
  fi
  if has_text "$ENTITLEMENTS_PATH" "com.apple.security.network.client"; then
    pass "Network client entitlement is present"
  else
    warn "Missing com.apple.security.network.client"
    blockers=$((blockers + 1))
  fi
else
  warn "Missing packaging/TokenMonitorMAS.entitlements"
  blockers=$((blockers + 1))
fi

if has_text "$ROOT_DIR/Package.swift" "TOKEN_MONITOR_MAS_BUILD" && has_text "$ROOT_DIR/Package.swift" "MAS_BUILD"; then
  pass "Package.swift has a TOKEN_MONITOR_MAS_BUILD path for a no-Sparkle app target"
elif has_text "$ROOT_DIR/Package.swift" "Sparkle"; then
  warn "Package.swift still depends on Sparkle without a MAS build switch"
  blockers=$((blockers + 1))
else
  pass "Package.swift does not reference Sparkle"
fi

if has_text "$ROOT_DIR/Sources/TokenMonitorApp/AppUpdateController.swift" "#if MAS_BUILD"; then
  pass "AppUpdateController has a no-Sparkle MAS path"
elif has_text "$ROOT_DIR/Sources/TokenMonitorApp/AppUpdateController.swift" "import Sparkle"; then
  warn "AppUpdateController imports Sparkle without a MAS no-op path"
  blockers=$((blockers + 1))
else
  pass "AppUpdateController does not import Sparkle"
fi

if [[ -f "$MAS_BUILD_SCRIPT" ]] && has_text "$MAS_BUILD_SCRIPT" "SUFeedURL"; then
  pass "MAS build script strips Sparkle update feed settings from Info.plist"
elif has_text "$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist" "SUFeedURL"; then
  warn "Info.plist contains SUFeedURL and no MAS stripping step was found"
  blockers=$((blockers + 1))
else
  pass "Info.plist does not contain SUFeedURL"
fi

if [[ -x "$MAS_BUILD_SCRIPT" ]]; then
  pass "MAS build script exists: scripts/build-mas-app.sh"
elif [[ -f "$MAS_BUILD_SCRIPT" ]]; then
  warn "MAS build script exists but is not executable: scripts/build-mas-app.sh"
  blockers=$((blockers + 1))
else
  warn "Missing scripts/build-mas-app.sh"
  blockers=$((blockers + 1))
fi

if has_text "$ROOT_DIR/Sources/TokenMonitorApp/ServiceSessionController.swift" "WKWebsiteDataStore.default()"; then
  warn "App uses persistent WebKit sessions; App Review notes and sandbox smoke tests are required"
else
  pass "Persistent WebKit session marker not found"
fi

if has_text "$ROOT_DIR/Sources/TokenMonitorApp/AppModel.swift" "SMAppService.mainApp"; then
  warn "App uses SMAppService login items; sandbox behavior must be smoke-tested"
else
  pass "SMAppService login item marker not found"
fi

cat <<EOF

MAS readiness summary:
- Blockers found: $blockers
- Primary distribution path remains Developer ID DMG.
- See docs/mac-app-store-feasibility.md for the full audit.

Recommended next MAS step:
1. Build with scripts/build-mas-app.sh.
2. Inspect the built app for Sparkle references and SU* Info.plist keys.
3. Sign with an Apple Distribution certificate when App Store Connect access exists.
4. Smoke-test WebKit login, refresh, snapshots, and Login Items under sandbox.
EOF
