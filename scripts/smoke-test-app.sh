#!/usr/bin/env bash
set -euo pipefail

if [[ "${CI:-}" != "true" ]]; then
  printf 'Run this startup check only on an isolated CI runner.\n' >&2
  exit 1
fi

app_path="${1:-dist/TokenMonitor.app}"
log_path="${RUNNER_TEMP:-/tmp}/token-monitor-startup.log"
"$app_path/Contents/MacOS/TokenMonitorApp" >"$log_path" 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true' EXIT

for attempt in {1..15}; do
  sleep 1
  if ! kill -0 "$app_pid" 2>/dev/null; then
    printf 'App terminated during the startup smoke test.\n' >&2
    cat "$log_path" >&2
    exit 1
  fi
done

printf 'App stayed alive through startup and notification initialization.\n'
