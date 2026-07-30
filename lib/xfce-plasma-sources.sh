#!/usr/bin/env bash
# Validated source configuration and shader-state migration helpers.

if [ -n "${XFCE_PLASMA_SOURCES_SH_LOADED:-}" ]; then
  return 0
fi
XFCE_PLASMA_SOURCES_SH_LOADED=1

if [ -z "${XFCE_PLASMA_COMMON_SH_LOADED:-}" ]; then
  source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  . "$source_dir/xfce-plasma-common.sh"
fi

xfce_plasma_source_valid_id() {
  local value=$1
  [ "${#value}" -le 128 ] || return 1
  case "$value" in
    ''|[.-]*|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

xfce_plasma_source_valid_type() {
  case "$1" in shader|video|stream|fallback) return 0 ;; *) return 1 ;; esac
}

xfce_plasma_source_canonical_shader_id() {
  local value=${1%.fs}
  case "${value,,}" in
    tie-dye|'tie dye'|plasma) printf 'plasma\n' ;;
    *) printf '%s\n' "$value" ;;
  esac
}

xfce_plasma_source_known_key() {
  case "$1" in
    type|id|display_name|path|url|loop|muted|fit|speed|backend|reconnect|reconnect_delay|latency|thumbnail|credential_file|capabilities)
      return 0 ;;
    *) return 1 ;;
  esac
}

xfce_plasma_source_value() {
  local file=$1 key=$2 fallback=${3:-} value
  xfce_plasma_source_known_key "$key" || return 2
  value=$(xfce_plasma_config_get "$file" "$key" 2>/dev/null || true)
  if [ -n "$value" ]; then printf '%s\n' "$value"; else printf '%s\n' "$fallback"; fi
}

xfce_plasma_source_validate_file() {
  local file=$1 raw key type id path url value
  [ -r "$file" ] || { printf 'Source configuration is unreadable: %s\n' "$file" >&2; return 1; }
  while IFS= read -r raw || [ -n "$raw" ]; do
    case "$raw" in ''|'#'*) continue ;; esac
    case "$raw" in *=*) ;; *) printf 'Invalid source configuration line in %s\n' "$file" >&2; return 1 ;; esac
    key=${raw%%=*}
    key=${key#${key%%[![:space:]]*}}
    key=${key%${key##*[![:space:]]}}
    xfce_plasma_source_known_key "$key" || {
      printf 'Unknown source key: %s\n' "$key" >&2
      return 1
    }
  done < "$file"

  type=$(xfce_plasma_source_value "$file" type)
  id=$(xfce_plasma_source_value "$file" id)
  xfce_plasma_source_valid_type "$type" || { printf 'Unknown source type: %s\n' "$type" >&2; return 1; }
  xfce_plasma_source_valid_id "$id" || { printf 'Invalid source ID: %s\n' "$id" >&2; return 1; }
  case "$type" in
    shader) ;;
    video)
      path=$(xfce_plasma_source_value "$file" path)
      case "$path" in /*) ;; *) printf 'Video path must be absolute: %s\n' "$path" >&2; return 1 ;; esac
      ;;
    stream)
      url=$(xfce_plasma_source_value "$file" url)
      case "$url" in rtsp://*) ;; *) printf 'Stream URL must use rtsp://\n' >&2; return 1 ;; esac
      case "$url" in *[[:space:]]*|*[[:cntrl:]]*) printf 'Stream URL contains invalid whitespace\n' >&2; return 1 ;; esac
      ;;
    fallback) ;;
  esac
  for key in loop muted reconnect; do
    value=$(xfce_plasma_source_value "$file" "$key")
    case "$value" in ''|true|false) ;; *) printf '%s must be true or false\n' "$key" >&2; return 1 ;; esac
  done
  value=$(xfce_plasma_source_value "$file" fit)
  case "$value" in ''|cover|contain|stretch) ;; *) printf 'Invalid fit mode: %s\n' "$value" >&2; return 1 ;; esac
  value=$(xfce_plasma_source_value "$file" backend)
  case "$value" in ''|automatic|mpv|vlc|raylib|static) ;; *) printf 'Invalid backend: %s\n' "$value" >&2; return 1 ;; esac
}

xfce_plasma_source_write_active() {
  local type=$1 id=$2 data
  xfce_plasma_source_valid_type "$type" || return 1
  xfce_plasma_source_valid_id "$id" || return 1
  data=$(printf 'type=%s\nid=%s\n' "$type" "$id")
  xfce_plasma_atomic_write "$XFCE_PLASMA_ACTIVE_SOURCE_FILE" "$data"
}

xfce_plasma_source_active_type() {
  xfce_plasma_source_value "$XFCE_PLASMA_ACTIVE_SOURCE_FILE" type shader
}

xfce_plasma_source_active_id() {
  local id
  id=$(xfce_plasma_source_value "$XFCE_PLASMA_ACTIVE_SOURCE_FILE" id plasma)
  if [ "$(xfce_plasma_source_active_type)" = shader ]; then
    xfce_plasma_source_canonical_shader_id "$id"
  else
    printf '%s\n' "$id"
  fi
}

xfce_plasma_source_migrate() {
  local legacy id type migration_log
  xfce_plasma_mkdirs
  if [ -s "$XFCE_PLASMA_ACTIVE_SOURCE_FILE" ]; then
    xfce_plasma_source_validate_file "$XFCE_PLASMA_ACTIVE_SOURCE_FILE"
    type=$(xfce_plasma_source_active_type)
    id=$(xfce_plasma_source_active_id)
    if [ "$type" = shader ] && [ "$(xfce_plasma_source_value "$XFCE_PLASMA_ACTIVE_SOURCE_FILE" id)" != "$id" ]; then
      xfce_plasma_source_write_active shader "$id"
    fi
    return 0
  fi

  legacy=plasma.fs
  if [ -s "$XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR/current-shader" ]; then
    legacy=$(sed -n '1p' "$XFCE_PLASMA_RENDERER_COMPAT_STATE_DIR/current-shader")
  fi
  id=$(xfce_plasma_source_canonical_shader_id "$legacy")
  xfce_plasma_source_valid_id "$id" || id=plasma
  xfce_plasma_source_write_active shader "$id"
  migration_log=$XFCE_PLASMA_LOG_DIR/migrations.log
  printf '%s component=sources event=migrate result=ok type=shader id=%s\n' \
    "$(date -Is)" "$id" >> "$migration_log"
  chmod 0600 "$migration_log" 2>/dev/null || true
}

xfce_plasma_redact_url() {
  printf '%s\n' "$1" |
    sed -E \
      -e 's#(rtsp://)[^/@]+(:[^/@]*)?@#\1***:***@#' \
      -e 's/([?&](pass(word)?|token|key|user(name)?)=)[^&]*/\1***/Ig'
}
