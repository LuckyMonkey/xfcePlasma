#!/usr/bin/env bash
# Shared path, environment, and small config helpers for xfcePlasma scripts.
# This file is meant to be sourced by Bash scripts.

if [ -n "${XFCE_PLASMA_COMMON_SH_LOADED:-}" ]; then
  return 0
fi
XFCE_PLASMA_COMMON_SH_LOADED=1

xfce_plasma_init() {
  : "${HOME:?HOME is required}"

  XFCE_PLASMA_HOME=$HOME
  XFCE_PLASMA_USER=$(id -un)
  XFCE_PLASMA_UID=$(id -u)

  XFCE_PLASMA_XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
  XFCE_PLASMA_XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
  XFCE_PLASMA_XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
  XFCE_PLASMA_XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
  XFCE_PLASMA_XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$XFCE_PLASMA_UID}

  XFCE_PLASMA_CONFIG_DIR=${XFCE_PLASMA_CONFIG_DIR:-$XFCE_PLASMA_XDG_CONFIG_HOME/xfce-plasma}
  XFCE_PLASMA_DATA_DIR=${XFCE_PLASMA_DATA_DIR:-$XFCE_PLASMA_XDG_DATA_HOME/xfce-plasma}
  XFCE_PLASMA_STATE_DIR=${XFCE_PLASMA_STATE_DIR:-$XFCE_PLASMA_XDG_STATE_HOME/xfce-plasma}
  XFCE_PLASMA_CACHE_DIR=${XFCE_PLASMA_CACHE_DIR:-$XFCE_PLASMA_XDG_CACHE_HOME/xfce-plasma}
  XFCE_PLASMA_RUN_DIR=${XFCE_PLASMA_RUN_DIR:-$XFCE_PLASMA_XDG_RUNTIME_DIR/xfce-plasma}
  XFCE_PLASMA_LOG_DIR=${XFCE_PLASMA_LOG_DIR:-$XFCE_PLASMA_STATE_DIR/logs}

  XFCE_PLASMA_PREFIX=${XFCE_PLASMA_PREFIX:-$HOME/.local}
  XFCE_PLASMA_BIN_DIR=${XFCE_PLASMA_BIN_DIR:-$XFCE_PLASMA_PREFIX/bin}
  XFCE_PLASMA_LIB_DIR=${XFCE_PLASMA_LIB_DIR:-$XFCE_PLASMA_PREFIX/lib/xfce-plasma}
  XFCE_PLASMA_XFDESKTOP_DIR=${XFCE_PLASMA_XFDESKTOP_DIR:-$XFCE_PLASMA_PREFIX/opt/xfdesktop-transparent}
  XFCE_PLASMA_RENDERER_DIR=${XFCE_PLASMA_RENDERER_DIR:-$XFCE_PLASMA_PREFIX/lib/tie-dye-wallpaper}
  XFCE_PLASMA_SHADER_DIR=${XFCE_PLASMA_SHADER_DIR:-$XFCE_PLASMA_DATA_DIR/shaders}
  XFCE_PLASMA_USER_SHADER_DIR=${XFCE_PLASMA_USER_SHADER_DIR:-$XFCE_PLASMA_DATA_DIR/user-shaders}
  # Compatibility path for the currently bundled renderer binary. The audit
  # found that it reads this legacy state path directly until source parity
  # work replaces it.
  XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR=${XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR:-$XFCE_PLASMA_XDG_STATE_HOME/tie-dye-wallpaper}

  XFCE_PLASMA_DISPLAY=${DISPLAY:-}
  XFCE_PLASMA_XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
  XFCE_PLASMA_DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XFCE_PLASMA_XDG_RUNTIME_DIR/bus}
}

xfce_plasma_export_session_env() {
  export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-$XFCE_PLASMA_XDG_RUNTIME_DIR}
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-$XFCE_PLASMA_DBUS_SESSION_BUS_ADDRESS}
  export XAUTHORITY=${XAUTHORITY:-$XFCE_PLASMA_XAUTHORITY}
  if [ -n "${XFCE_PLASMA_DISPLAY:-}" ]; then
    export DISPLAY=${DISPLAY:-$XFCE_PLASMA_DISPLAY}
  fi
}

xfce_plasma_mkdirs() {
  mkdir -p "$XFCE_PLASMA_CONFIG_DIR" "$XFCE_PLASMA_DATA_DIR" \
    "$XFCE_PLASMA_STATE_DIR" "$XFCE_PLASMA_CACHE_DIR" \
    "$XFCE_PLASMA_RUN_DIR" "$XFCE_PLASMA_LOG_DIR" \
    "$XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR"
  chmod 700 "$XFCE_PLASMA_RUN_DIR" 2>/dev/null || true
}

xfce_plasma_atomic_write() {
  path=$1
  data=$2
  dir=$(dirname "$path")
  base=$(basename "$path")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.$base.XXXXXX") || return 1
  printf '%s\n' "$data" > "$tmp"
  chmod 0600 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$path"
}

xfce_plasma_config_get() {
  file=$1
  key=$2
  [ -r "$file" ] || return 1
  awk -v want="$key" '
    /^[[:space:]]*($|#)/ { next }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      split(line, parts, "=")
      k = parts[1]
      sub(/[[:space:]]+$/, "", k)
      if (k == want) {
        sub(/^[^=]*=/, "", line)
        sub(/^[[:space:]]+/, "", line)
        sub(/[[:space:]]+$/, "", line)
        print line
        found = 1
        exit
      }
    }
    END { if (!found) exit 1 }
  ' "$file"
}

xfce_plasma_restart_desktop_stack() {
  local wallpaper_unit=${1:-tie-dye-wallpaper-mvp.service}
  local desktop_unit=${2:-xfdesktop-transparent.service}
  local settle_seconds=${WALLPAPER_STACK_SETTLE_SECONDS:-1}
  local status=0

  systemctl --user stop "$desktop_unit" || true
  systemctl --user restart "$wallpaper_unit" || status=$?
  sleep "$settle_seconds"
  systemctl --user start "$desktop_unit" || status=$?
  return "$status"
}

xfce_plasma_init
