#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HOME="$tmp/home"
XDG_STATE_HOME="$tmp/state"
mkdir -p "$HOME" "$XDG_STATE_HOME"

out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" frozen)
[ "$out" = "frozen" ]
[ "$(cat "$XDG_STATE_HOME/tie-dye-wallpaper/speed")" = "0.0" ]
[ "$(cat "$XDG_STATE_HOME/tie-dye-wallpaper/speed-label")" = "frozen" ]

out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" up)
[ "$out" = "slow" ]
[ "$(cat "$XDG_STATE_HOME/tie-dye-wallpaper/speed")" = "0.35" ]

out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" value)
[ "$out" = "0.35" ]

printf 'test-speed ok\n'
