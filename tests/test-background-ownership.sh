#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
guard="$repo_root/bin/game-mode-guard"
restart_helper="$repo_root/bin/restart-animated-wallpaper-renderer"

if grep -Eq 'IDLE_REPAIR_SECONDS|idle repair|xfce_plasma_restart_desktop_stack|xfdesktop-transparent' \
    "$guard" "$restart_helper"; then
    printf 'FAIL: background recovery must not restart or watchdog the xfdesktop icon stack\n' >&2
    exit 1
fi

grep -Fq 'systemctl --user start "$WALLPAPER_UNIT"' "$guard"
grep -Fq 'systemctl --user restart tie-dye-wallpaper-mvp.service' "$restart_helper"

printf 'background process ownership tests passed\n'
