#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
site_dir="$repo_root/dist/pages-site"

if [[ -e "$site_dir" ]]; then
  backup_dir="$repo_root/dist/pages-site.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$site_dir" "$backup_dir"
  printf 'Previous Pages bundle moved to %s\n' "$backup_dir"
fi

mkdir -p "$site_dir"
cp -R "$repo_root/assets" "$site_dir/assets"
sed 's#\.\./assets/#assets/#g' "$repo_root/landing/index.html" > "$site_dir/index.html"
cp "$repo_root/landing/app.js" "$site_dir/app.js"
cp "$repo_root/landing/_headers" "$site_dir/_headers"
find "$site_dir" -name '.DS_Store' -delete

required=(
  "$site_dir/index.html"
  "$site_dir/app.js"
  "$site_dir/_headers"
  "$site_dir/assets/branding/token-monitor-logo.png"
  "$site_dir/assets/screenshots/app/dashboard.png"
  "$site_dir/assets/screenshots/app/claude.png"
  "$site_dir/assets/screenshots/app/chatgpt.png"
)

for file in "${required[@]}"; do
  if [[ ! -s "$file" ]]; then
    printf 'Missing or empty Pages asset: %s\n' "$file" >&2
    exit 1
  fi
done

if rg -q '\.\./assets/' "$site_dir/index.html"; then
  printf 'Pages index still contains repository-relative asset paths.\n' >&2
  exit 1
fi

printf 'Built Cloudflare Pages bundle at %s\n' "$site_dir"
