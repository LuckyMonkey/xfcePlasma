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
"$tool" grime-signal --time 12 --size 160x90 --output "$tmp/one.png" >/dev/null 2>&1
file "$tmp/one.png" | grep -q 'PNG image data'
test -s "$tmp/one.png"
identify -format '%wx%h' "$tmp/one.png" | grep -qx '160x90'
sha256sum "$tmp/one.png" > "$tmp/hash1"
"$tool" grime-signal --time 12 --size 160x90 --output "$tmp/two.png" >/dev/null 2>&1
[ "$(convert "$tmp/one.png" RGBA:- | sha256sum | awk '{print $1}')" = "$(convert "$tmp/two.png" RGBA:- | sha256sum | awk '{print $1}')" ]
if "$tool" does-not-exist --output "$tmp/bad.png" >/tmp/tool-bad 2>&1; then exit 1; fi
grep -q 'shader not found' /tmp/tool-bad
"$tool" --gallery --size 80x45 --output-dir "$tmp/gallery" >/dev/null 2>&1
[ "$(find "$tmp/gallery" -name '*.png' | wc -l)" -eq 12 ]
[ ! -e "$tmp/gallery/glyph-diagnostic.png" ]
if "$tool" glyph-diagnostic --output "$tmp/hidden.png" >/dev/null 2>&1; then exit 1; fi
"$frames" ricky --output-dir "$tmp/ricky" >/dev/null 2>&1
[ "$(find "$tmp/ricky" -name '*.png' | wc -l)" -eq 4 ]
bench=$("$tool" grime-signal --benchmark 0.25 --size 160x90 --json 2>/dev/null)
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["frames"] > 0 and d["approx_fps"] > 0 and d["resolution"] == "160x90"' "$bench"
printf 'test-render-shader-tool ok\n'
