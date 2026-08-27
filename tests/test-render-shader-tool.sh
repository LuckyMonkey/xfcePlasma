#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tool=$repo_root/bin/xfce-plasma-render-shader
frames=$repo_root/bin/xfce-plasma-render-shader-frames
shader_dir=$repo_root/runtime/tie-dye-wallpaper/shaders
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export WALLPAPER_SHADER_DIR="$shader_dir" WALLPAPER_USER_SHADER_DIR="$tmp/no-user"
"$repo_root/build/xfce-plasma-renderer" --help | grep -q -- '--no-random-phase'
"$repo_root/build/xfce-plasma-renderer" --version | grep -q '^xfce-plasma-renderer '
if "$repo_root/build/xfce-plasma-renderer" --unknown-option >/dev/null 2>&1; then exit 1; fi
if "$repo_root/build/xfce-plasma-renderer" --wid garbage >/dev/null 2>&1; then exit 1; fi
if "$repo_root/build/xfce-plasma-renderer" --wid >/dev/null 2>&1; then exit 1; fi
if "$tool" grime-signal --size 0x90 --output "$tmp/bad.png" >/dev/null 2>&1; then exit 1; fi
if "$tool" grime-signal --time nope --output "$tmp/bad.png" >/dev/null 2>&1; then exit 1; fi
for bad in 0 -1 nan inf nonsense; do
  if "$tool" grime-signal --benchmark "$bad" --json >/dev/null 2>&1; then exit 1; fi
done
"$tool" grime-signal --time 12 --size 160x90 --output "$tmp/one.png" >/dev/null 2>&1
file "$tmp/one.png" | grep -q 'PNG image data'
test -s "$tmp/one.png"
identify -format '%wx%h' "$tmp/one.png" | grep -qx '160x90'
"$tool" grime-melting-ice-cream --time 0 --size 160x90 --output "$tmp/ice0.png" >/dev/null 2>&1
"$tool" grime-melting-ice-cream --time 15 --size 160x90 --output "$tmp/ice15.png" >/dev/null 2>&1
if cmp -s "$tmp/ice0.png" "$tmp/ice15.png"; then printf 'melting ice cream shader has no visible time variation\n' >&2; exit 1; fi
sha256sum "$tmp/one.png" > "$tmp/hash1"
"$tool" grime-signal --time 12 --size 160x90 --output "$tmp/two.png" >/dev/null 2>&1
[ "$(convert "$tmp/one.png" RGBA:- | sha256sum | awk '{print $1}')" = "$(convert "$tmp/two.png" RGBA:- | sha256sum | awk '{print $1}')" ]
if "$tool" does-not-exist --output "$tmp/bad.png" >/tmp/tool-bad 2>&1; then exit 1; fi
grep -q 'shader not found' /tmp/tool-bad
"$tool" --gallery --size 80x45 --output-dir "$tmp/gallery" >/dev/null 2>&1
[ "$(find "$tmp/gallery" -name '*.png' | wc -l)" -eq 13 ]
[ ! -e "$tmp/gallery/glyph-diagnostic.png" ]
if "$tool" glyph-diagnostic --output "$tmp/hidden.png" >/dev/null 2>&1; then exit 1; fi
"$frames" ricky --output-dir "$tmp/ricky" >/dev/null 2>&1
[ "$(find "$tmp/ricky" -name '*.png' | wc -l)" -eq 4 ]
bench=$("$tool" grime-signal --benchmark 0.25 --size 160x90 --json 2>/dev/null)
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["frames"] > 0 and d["elapsed_seconds"] > 0 and d["percentile_method"] == "nearest_rank" and d["average_frame_ms"] > 0 and d["min_frame_ms"] <= d["median_frame_ms"] <= d["max_frame_ms"] and d["min_frame_ms"] <= d["p95_frame_ms"] <= d["max_frame_ms"] and abs(d["approx_fps"] - d["frames"] / d["elapsed_seconds"]) < 5 and abs(d["approx_fps"] - 1000 / d["average_frame_ms"]) < 5 and d["resolution"] == "160x90"' "$bench"
printf 'test-render-shader-tool ok\n'
