#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="${TOKEN_MONITOR_APP_INFO_PLIST:-$ROOT_DIR/Sources/TokenMonitorApp/Resources/Info.plist}"
RELEASE_TAG="${TOKEN_MONITOR_RELEASE_TAG:-${RELEASE_TAG:-}}"
REQUIRE_TAG=0
failures=0

usage() {
  cat <<'EOF'
Usage: ./scripts/check-release-version-consistency.sh [--tag <tag>] [--require-tag]

Checks that Token Monitor's Info.plist version/build values are release-safe
and, when a tag is provided, that the release tag matches the app version.

Options:
  --tag <tag>      Release tag to compare against CFBundleShortVersionString.
  --require-tag    Exit non-zero if no tag is provided.
  -h, --help       Show this help.

Environment:
  RELEASE_TAG or TOKEN_MONITOR_RELEASE_TAG  Alternative way to provide the tag.
  TOKEN_MONITOR_APP_INFO_PLIST              Override Info.plist path.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for --tag\n' >&2
        exit 2
      fi
      RELEASE_TAG="$2"
      shift 2
      ;;
    --require-tag)
      REQUIRE_TAG=1
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
  printf '[WARN] %s\n' "$1"
  failures=$((failures + 1))
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

printf 'Token Monitor release version consistency\n\n'
printf 'Info.plist: %s\n' "$INFO_PLIST"
if [[ -n "$RELEASE_TAG" ]]; then
  printf 'Release tag: %s\n\n' "$RELEASE_TAG"
else
  printf 'Release tag: not provided\n\n'
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  printf '[FAIL] Info.plist not found: %s\n' "$INFO_PLIST" >&2
  exit 1
fi

version="$(plist_value CFBundleShortVersionString)"
build="$(plist_value CFBundleVersion)"

if [[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
  pass "CFBundleShortVersionString is semantic version-like: $version"
else
  warn "CFBundleShortVersionString should look like MAJOR.MINOR.PATCH: $version"
fi

if [[ "$build" =~ ^[0-9]+$ && "$build" -gt 0 ]]; then
  pass "CFBundleVersion is a positive integer: $build"
else
  warn "CFBundleVersion should be a positive integer: $build"
fi

if [[ -n "$RELEASE_TAG" ]]; then
  expected_tag="v$version"
  if [[ "$RELEASE_TAG" == "$expected_tag" ]]; then
    pass "Release tag matches app version: $RELEASE_TAG"
  else
    warn "Release tag $RELEASE_TAG does not match app version $version; expected $expected_tag"
  fi
elif [[ "$REQUIRE_TAG" == "1" ]]; then
  warn "Release tag is required"
else
  pass "Release tag comparison skipped"
fi

printf '\nVersion consistency summary:\n'
printf -- '- Failure count: %s\n' "$failures"

if [[ "$failures" -gt 0 ]]; then
  printf '[FAIL] Release version consistency check failed\n' >&2
  exit 1
fi

pass "Release version consistency is clean"
