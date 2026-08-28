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
  XFCE_PLASMA_ASSET_DIR=${XFCE_PLASMA_ASSET_DIR:-$XFCE_PLASMA_DATA_DIR/assets}
  XFCE_PLASMA_THUMBNAIL_DIR=${XFCE_PLASMA_THUMBNAIL_DIR:-$XFCE_PLASMA_ASSET_DIR/thumbnails}
  XFCE_PLASMA_STATE_DIR=${XFCE_PLASMA_STATE_DIR:-$XFCE_PLASMA_XDG_STATE_HOME/xfce-plasma}
  XFCE_PLASMA_CACHE_DIR=${XFCE_PLASMA_CACHE_DIR:-$XFCE_PLASMA_XDG_CACHE_HOME/xfce-plasma}
  XFCE_PLASMA_RUN_DIR=${XFCE_PLASMA_RUN_DIR:-$XFCE_PLASMA_XDG_RUNTIME_DIR/xfce-plasma}
  XFCE_PLASMA_LOG_DIR=${XFCE_PLASMA_LOG_DIR:-$XFCE_PLASMA_STATE_DIR/logs}
  XFCE_PLASMA_SOURCE_DIR=${XFCE_PLASMA_SOURCE_DIR:-$XFCE_PLASMA_CONFIG_DIR/sources}
  XFCE_PLASMA_CREDENTIAL_DIR=${XFCE_PLASMA_CREDENTIAL_DIR:-$XFCE_PLASMA_CONFIG_DIR/credentials}
  XFCE_PLASMA_ACTIVE_SOURCE_FILE=${XFCE_PLASMA_ACTIVE_SOURCE_FILE:-$XFCE_PLASMA_STATE_DIR/active-source}
  XFCE_PLASMA_SETTINGS_FILE=${XFCE_PLASMA_SETTINGS_FILE:-$XFCE_PLASMA_CONFIG_DIR/settings.conf}
  XFCE_PLASMA_PERFORMANCE_PROFILE_FILE=${XFCE_PLASMA_PERFORMANCE_PROFILE_FILE:-$XFCE_PLASMA_CACHE_DIR/performance-profile}
  XFCE_PLASMA_BACKEND_STATE_FILE=${XFCE_PLASMA_BACKEND_STATE_FILE:-$XFCE_PLASMA_RUN_DIR/backend.state}
  XFCE_PLASMA_BACKEND_STATUS_FILE=${XFCE_PLASMA_BACKEND_STATUS_FILE:-$XFCE_PLASMA_RUN_DIR/backend.status}

  XFCE_PLASMA_PREFIX=${XFCE_PLASMA_PREFIX:-$HOME/.local}
  XFCE_PLASMA_BIN_DIR=${XFCE_PLASMA_BIN_DIR:-$XFCE_PLASMA_PREFIX/bin}
  XFCE_PLASMA_LIB_DIR=${XFCE_PLASMA_LIB_DIR:-$XFCE_PLASMA_PREFIX/lib/xfce-plasma}
  XFCE_PLASMA_VERSION_FILE=${XFCE_PLASMA_VERSION_FILE:-$XFCE_PLASMA_LIB_DIR/VERSION}
  XFCE_PLASMA_INSTALL_ORIGIN_FILE=${XFCE_PLASMA_INSTALL_ORIGIN_FILE:-$XFCE_PLASMA_LIB_DIR/install-origin}
  XFCE_PLASMA_XFDESKTOP_DIR=${XFCE_PLASMA_XFDESKTOP_DIR:-$XFCE_PLASMA_PREFIX/opt/xfdesktop-transparent}
  XFCE_PLASMA_RENDERER_DIR=${XFCE_PLASMA_RENDERER_DIR:-$XFCE_PLASMA_PREFIX/lib/tie-dye-wallpaper}
  XFCE_PLASMA_SHADER_DIR=${XFCE_PLASMA_SHADER_DIR:-$XFCE_PLASMA_DATA_DIR/shaders}
  XFCE_PLASMA_USER_SHADER_DIR=${XFCE_PLASMA_USER_SHADER_DIR:-$XFCE_PLASMA_DATA_DIR/user-shaders}
  XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR=${XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR:-$XFCE_PLASMA_XDG_STATE_HOME/tie-dye-wallpaper}

  XFCE_PLASMA_DISPLAY=${DISPLAY:-}
  XFCE_PLASMA_XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
  XFCE_PLASMA_DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XFCE_PLASMA_XDG_RUNTIME_DIR/bus}
}

xfce_plasma_project_version() {
  local library_dir source_version
  if [ -r "$XFCE_PLASMA_VERSION_FILE" ]; then
    sed -n '1p' "$XFCE_PLASMA_VERSION_FILE"
    return 0
  fi
  library_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for source_version in "$library_dir/VERSION" "$library_dir/../VERSION"; do
    if [ -r "$source_version" ]; then
      sed -n '1p' "$source_version"
      return 0
    fi
  done
  printf 'unknown\n'
}

xfce_plasma_install_origin() {
  if [ -r "$XFCE_PLASMA_INSTALL_ORIGIN_FILE" ]; then
    sed -n '1p' "$XFCE_PLASMA_INSTALL_ORIGIN_FILE"
  elif [ -x "$XFCE_PLASMA_RENDERER_DIR/tie-dye-wallpaper" ]; then
    printf 'legacy-or-unknown\n'
  else
    printf 'not-installed\n'
  fi
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
    "$XFCE_PLASMA_SOURCE_DIR" "$XFCE_PLASMA_CREDENTIAL_DIR" \
    "$XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR"
  chmod 700 "$XFCE_PLASMA_RUN_DIR" "$XFCE_PLASMA_CREDENTIAL_DIR" 2>/dev/null || true
}

xfce_plasma_atomic_write() {
  local path=$1 data=$2 dir base tmp
  dir=$(dirname "$path")
  base=$(basename "$path")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.$base.XXXXXX") || return 1
  printf '%s\n' "$data" > "$tmp"
  chmod 0600 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$path"
}

xfce_plasma_atomic_copy() {
  local source=$1 path=$2 dir base tmp
  dir=$(dirname "$path")
  base=$(basename "$path")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.$base.XXXXXX") || return 1
  if ! cp -f -- "$source" "$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  chmod 0644 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$path"
}

xfce_plasma_config_get() {
  local file=$1 key=$2
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

xfce_plasma_wait_unit_active() {
  local unit=$1 attempts=${2:-20} delay=${3:-0.1} i
  for ((i = 0; i < attempts; i++)); do
    systemctl --user is-active --quiet "$unit" 2>/dev/null && return 0
    sleep "$delay"
  done
  return 1
}

xfce_plasma_backend_visible() {
  local state pid window map_state
  [ -r "$XFCE_PLASMA_BACKEND_STATE_FILE" ] || return 1
  state=$(xfce_plasma_config_get "$XFCE_PLASMA_BACKEND_STATE_FILE" state 2>/dev/null || true)
  pid=$(xfce_plasma_config_get "$XFCE_PLASMA_BACKEND_STATE_FILE" backend_pid 2>/dev/null || true)
  window=$(xfce_plasma_config_get "$XFCE_PLASMA_BACKEND_STATE_FILE" window_id 2>/dev/null || true)

  [ "$state" = running ] || return 1
  case "$pid" in ''|*[!0-9]*|0|1) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null || return 1
  case "$window" in 0x*|0X*|[0-9]*) ;; *) return 1 ;; esac

  if command -v xwininfo >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    map_state=$(xwininfo -id "$window" 2>/dev/null | awk -F: '/Map State:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}')
    [ "$map_state" = IsViewable ] && return 0
    return 1
  fi

  if command -v xprop >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    xprop -id "$window" >/dev/null 2>&1 && return 0
    return 1
  fi

  # On minimal systems without X11 inspection tools, a live backend PID plus
  # a populated xwinwrap window is the strongest readiness signal available.
  return 0
}

xfce_plasma_wait_background_visible() {
  local unit=${1:-tie-dye-wallpaper-mvp.service} attempts=${2:-40} delay=${3:-0.1} i
  for ((i = 0; i < attempts; i++)); do
    systemctl --user is-active --quiet "$unit" 2>/dev/null || return 1
    xfce_plasma_backend_visible && return 0
    sleep "$delay"
  done
  return 1
}


xfce_plasma_restart_desktop_stack() {
  local wallpaper_unit=${1:-tie-dye-wallpaper-mvp.service}
  local desktop_unit=${2:-xfdesktop-transparent.service}
  local settle_seconds=${WALLPAPER_STACK_SETTLE_SECONDS:-1}
  local status=0

  systemctl --user stop "$desktop_unit" >/dev/null 2>&1 || true

  if ! systemctl --user restart "$wallpaper_unit"; then
    printf 'Failed to restart wallpaper service: %s\n' "$wallpaper_unit" >&2
    status=1
  elif ! xfce_plasma_wait_unit_active "$wallpaper_unit"; then
    printf 'Wallpaper service did not become active: %s\n' "$wallpaper_unit" >&2
    status=1
  elif ! xfce_plasma_wait_background_visible "$wallpaper_unit"; then
    printf 'Wallpaper service is active but no viewable backend window appeared: %s\n' "$wallpaper_unit" >&2
    status=1
  fi

  sleep "$settle_seconds"

  if ! systemctl --user start "$desktop_unit"; then
    printf 'Failed to start desktop icon service: %s\n' "$desktop_unit" >&2
    status=1
  elif ! xfce_plasma_wait_unit_active "$desktop_unit"; then
    printf 'Desktop icon service did not become active: %s\n' "$desktop_unit" >&2
    status=1
  fi

  return "$status"
}

xfce_plasma_init
