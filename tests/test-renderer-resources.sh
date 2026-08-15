#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
renderer="$repo_root/src/renderer/main.c"
shader="$repo_root/runtime/tie-dye-wallpaper/shaders/hello-kitty-dmx-font.fs"

require() {
  local pattern=$1 file=$2 message=$3
  if ! rg -q -- "$pattern" "$file"; then
    printf 'renderer resource regression: %s\n' "$message" >&2
    exit 1
  fi
}

reject() {
  local pattern=$1 file=$2 message=$3
  if rg -q -- "$pattern" "$file"; then
    printf 'renderer resource regression: %s\n' "$message" >&2
    exit 1
  fi
}

require 'WALLPAPER_SHADER_FILE' "$renderer" 'explicit shader override disappeared'
require '/proc/self/exe' "$renderer" 'installed shader path is no longer executable-relative'
require 'open_shader_watch\(shader_path\)' "$renderer" 'shader watcher is no longer tied to the resolved shader path'
require 'WALLPAPER_GLYPH_ATLAS' "$renderer" 'optional glyph atlas override disappeared'
require 'using shader built-in glyphs' "$renderer" 'missing-atlas fallback is no longer diagnosed'
require 'set_shader_float' "$renderer" 'optional shader uniform writes are no longer guarded'
require 'fallbackGlyph' "$shader" 'DMX shader lost its built-in glyph fallback'
require 'hash\(vec2\(fi, 7\.0\)\) \* 6\.0' "$shader" 'DMX shader no longer selects all six glyphs'
reject '/home/freezer' "$renderer" 'personal home path reintroduced into renderer'
reject '#define ACTIVE_SHADER_PATH "shader\.fs"' "$renderer" 'renderer reverted to cwd-only shader lookup'

printf 'test-renderer-resources ok\n'
