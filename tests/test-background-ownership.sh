#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
guard="$repo_root/bin/game-mode-guard"
restart_helper="$repo_root/bin/restart-animated-wallpaper-renderer"
restack_helper="$repo_root/bin/xfce-plasma-restack-icons"
background_unit="$repo_root/systemd/user/tie-dye-wallpaper-mvp.service"

if grep -Eq 'IDLE_REPAIR_SECONDS|idle repair|xfce_plasma_restart_desktop_stack|xfdesktop-transparent' \
    "$guard" "$restart_helper"; then
    printf 'FAIL: background recovery must not restart or watchdog the xfdesktop icon stack\n' >&2
    exit 1
fi

grep -Fq 'systemctl --user start "$WALLPAPER_UNIT"' "$guard"
grep -Fq 'systemctl --user restart tie-dye-wallpaper-mvp.service' "$restart_helper"
grep -Fq 'xdotool windowraise "$desktop_window"' "$restack_helper"
grep -Fq 'ExecStartPost=%h/.local/bin/xfce-plasma-restack-icons' "$background_unit"
grep -Fq 'xfce-plasma-restack-icons' "$repo_root/install.sh"

if grep -Eq 'systemctl.*(restart|stop).*xfdesktop' "$restack_helper"; then
    printf 'FAIL: icon restacking must not restart xfdesktop\n' >&2
    exit 1
fi

printf 'background process ownership tests passed\n'
