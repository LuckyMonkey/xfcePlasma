#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
renderer="$repo_root/src/renderer/main.c"
shader="$repo_root/runtime/tie-dye-wallpaper/shaders/hello-kitty-dancefloor.fs"
diagnostic="$repo_root/runtime/tie-dye-wallpaper/shaders/glyph-diagnostic.fs"
wallpaper_service="$repo_root/systemd/user/tie-dye-wallpaper-mvp.service"
desktop_service="$repo_root/systemd/user/xfdesktop-transparent.service"
game_service="$repo_root/systemd/user/game-mode-guard.service"
common="$repo_root/lib/xfce-plasma-common.sh"

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
require 'frontKitty' "$shader" 'dancefloor shader lost its front sprite frame'
require 'profileKitty' "$shader" 'dancefloor shader lost its rotating profile frame'
require 'backKitty' "$shader" 'dancefloor shader lost its back sprite frame'
require 'CAT_COUNT=8' "$shader" 'dancefloor shader lost independent multi-sprite choreography'
require 'fallbackGlyph' "$diagnostic" 'glyph diagnostic no longer renders the built-in glyph path'
require 'atlasGlyph' "$diagnostic" 'glyph diagnostic no longer renders the atlas path'
require 'Restart=on-failure' "$wallpaper_service" 'wallpaper service crash recovery disappeared'
require 'KillMode=control-group' "$wallpaper_service" 'wallpaper service no longer owns its backend process group'
require 'Restart=on-failure' "$desktop_service" 'desktop icon service crash recovery disappeared'
require 'After=.*tie-dye-wallpaper-mvp.service' "$desktop_service" 'desktop icon service no longer orders after the wallpaper service'
require 'Restart=on-failure' "$game_service" 'game mode guard crash recovery disappeared'
require 'xfce_plasma_wait_unit_active' "$common" 'desktop stack restart no longer verifies service startup'
require 'xfce_plasma_wait_background_visible' "$common" 'desktop stack no longer verifies a visible background window'
reject "$(printf '/home/%s' freezer)" "$renderer" 'personal home path reintroduced into renderer'
reject '#define ACTIVE_SHADER_PATH "shader\.fs"' "$renderer" 'renderer reverted to cwd-only shader lookup'
reject 'glyphAtlasValid' "$shader" 'DMX shader accidentally depends on an unwired atlas-validity uniform'

printf 'test-renderer-resources ok\n'
