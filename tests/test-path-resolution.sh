#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HOME="$tmp/Home With Spaces"
mkdir -p "$HOME"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR
unset DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS

# shellcheck source=../lib/xfce-plasma-common.sh
. "$repo_root/lib/xfce-plasma-common.sh"

[ "$XFCE_PLASMA_HOME" = "$HOME" ]
[ "$XFCE_PLASMA_CONFIG_DIR" = "$HOME/.config/xfce-plasma" ]
[ "$XFCE_PLASMA_DATA_DIR" = "$HOME/.local/share/xfce-plasma" ]
[ "$XFCE_PLASMA_STATE_DIR" = "$HOME/.local/state/xfce-plasma" ]
[ "$XFCE_PLASMA_CACHE_DIR" = "$HOME/.cache/xfce-plasma" ]
[ "$XFCE_PLASMA_XDG_RUNTIME_DIR" = "/run/user/$(id -u)" ]
[ "$XFCE_PLASMA_XAUTHORITY" = "$HOME/.Xauthority" ]
[ "$XFCE_PLASMA_DBUS_SESSION_BUS_ADDRESS" = "unix:path=/run/user/$(id -u)/bus" ]
[ -z "$XFCE_PLASMA_DISPLAY" ]

printf 'test-path-resolution ok\n'
