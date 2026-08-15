#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shader_dir=$repo_root/runtime/tie-dye-wallpaper/shaders
thumbnail_dir=$repo_root/assets/thumbnails
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# shellcheck source=../lib/xfce-plasma-common.sh
. "$repo_root/lib/xfce-plasma-common.sh"

[ -f "$thumbnail_dir/fallback.png" ]
shader_count=0
: > "$tmp/ids"
: > "$tmp/orders"
for shader in "$shader_dir"/*.fs; do
  base=${shader##*/}
  base=${base%.fs}
  meta=$shader_dir/$base.meta
  [ -r "$meta" ] || { printf 'missing metadata: %s\n' "$shader" >&2; exit 1; }
  id=$(xfce_plasma_config_get "$meta" id)
  display=$(xfce_plasma_config_get "$meta" display_name)
  category=$(xfce_plasma_config_get "$meta" category)
  description=$(xfce_plasma_config_get "$meta" description)
  thumbnail=$(xfce_plasma_config_get "$meta" thumbnail)
  order=$(xfce_plasma_config_get "$meta" sort_order)
  [ "$id" = "$base" ]
  [ -n "$display" ]
  [ -n "$description" ]
  case "$category" in Ambient|Graphic|Scenic|Experimental|Diagnostics) ;; *) printf 'invalid category: %s\n' "$category" >&2; exit 1 ;; esac
  case "$order" in ''|*[!0-9]*) printf 'invalid sort order: %s\n' "$order" >&2; exit 1 ;; esac
  [ "$thumbnail" = "$id.png" ]
  [ -r "$thumbnail_dir/$thumbnail" ]
  file "$thumbnail_dir/$thumbnail" | grep -q 'PNG image data'
  printf '%s\n' "$id" >> "$tmp/ids"
  printf '%s\n' "$order" >> "$tmp/orders"
  shader_count=$((shader_count + 1))
done
[ "$shader_count" -eq 14 ]
[ "$(sort -u "$tmp/ids" | wc -l)" -eq "$shader_count" ]
[ "$(sort -u "$tmp/orders" | wc -l)" -eq "$shader_count" ]
if rg -i 'stunning|immersive|next-generation' "$shader_dir"/*.meta; then
  printf 'metadata contains disallowed marketing language\n' >&2
  exit 1
fi

printf 'test-gallery-assets ok\n'
