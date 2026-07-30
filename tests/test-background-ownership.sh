#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
guard="$repo_root/bin/game-mode-guard"
restart_helper="$repo_root/bin/restart-animated-wallpaper-renderer"
background_unit="$repo_root/systemd/user/tie-dye-wallpaper-mvp.service"

if grep -Eq 'IDLE_REPAIR_SECONDS|idle repair' "$guard"; then
    printf 'FAIL: game guard must not continuously watchdog the background\n' >&2
    exit 1
fi

grep -Fq 'xfce_plasma_restart_desktop_stack tie-dye-wallpaper-mvp.service xfdesktop-transparent.service' "$restart_helper"
grep -Fq 'restart_background_stack' "$repo_root/bin/xfce-plasma-background"
if grep -Eq '^Restart=' "$background_unit"; then
    printf 'FAIL: automatic background restarts can cover the xfdesktop icon layer\n' >&2
    exit 1
fi

printf 'background process ownership tests passed\n'
