#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_name="${PAGES_PROJECT_NAME:-token-monitor-landing}"
pages_url="${PAGES_URL:-https://token-monitor-landing.pages.dev}"

"$repo_root/scripts/build-pages-site.sh"

if ! wrangler pages project list | rg -q "(^|[[:space:]])${project_name}([[:space:]]|$)"; then
  wrangler pages project create "$project_name" --production-branch main
fi

wrangler pages deploy "$repo_root/dist/pages-site" \
  --project-name "$project_name" \
  --branch main \
  --commit-dirty=true

printf 'Cloudflare Pages target: %s\n' "$pages_url"
