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

out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" fast)
[ "$out" = "fast" ]
[ "$(cat "$XDG_STATE_HOME/tie-dye-wallpaper/speed")" = "1.75" ]
out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" freeze)
[ "$out" = "frozen" ]
out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" restore)
[ "$out" = "fast" ]
[ "$(cat "$XDG_STATE_HOME/tie-dye-wallpaper/speed")" = "1.75" ]
out=$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" set 3.2)
[ "$out" = "custom" ]
[ "$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" get)" = "3.2" ]
if HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" set -1 >/dev/null 2>&1; then
  printf 'invalid speed unexpectedly accepted\n' >&2
  exit 1
fi
[ "$(HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" "$repo_root/bin/animated-wallpaper-speed" get)" = "3.2" ]

printf 'test-speed ok\n'
