#!/usr/bin/env bash
# Cached, feature-based background performance profile detection.

if [ -n "${XFCE_PLASMA_PERFORMANCE_SH_LOADED:-}" ]; then
  return 0
fi
XFCE_PLASMA_PERFORMANCE_SH_LOADED=1

if [ -z "${XFCE_PLASMA_COMMON_SH_LOADED:-}" ]; then
  performance_source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  . "$performance_source_dir/xfce-plasma-common.sh"
fi

xfce_plasma_performance_mode() {
  local mode
  mode=$(xfce_plasma_config_get "$XFCE_PLASMA_SETTINGS_FILE" performance_mode 2>/dev/null || printf automatic)
  case "${mode,,}" in automatic|low|balanced|high) printf '%s\n' "${mode,,}" ;; *) printf 'automatic\n' ;; esac
}

xfce_plasma_performance_set_mode() {
  local mode=${1,,} old_data= data
  case "$mode" in automatic|low|balanced|high) ;; *) printf 'Performance mode must be Automatic, Low, Balanced, or High.\n' >&2; return 2 ;; esac
  if [ -r "$XFCE_PLASMA_SETTINGS_FILE" ]; then
    old_data=$(awk -F= '$1 != "performance_mode" { print }' "$XFCE_PLASMA_SETTINGS_FILE")
  fi
  data=${old_data:+$old_data$'\n'}performance_mode=$mode
  xfce_plasma_atomic_write "$XFCE_PLASMA_SETTINGS_FILE" "$data"
  rm -f -- "$XFCE_PLASMA_PERFORMANCE_PROFILE_FILE"
}

xfce_plasma_performance_gl_field() {
  local label=$1 fallback=$2 report=${3:-}
  if [ -z "$report" ] && command -v glxinfo >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    report=$(glxinfo -B 2>/dev/null || true)
  fi
  awk -F': ' -v label="$label" -v fallback="$fallback" '$1 == label { print $2; found=1; exit } END { if (!found) print fallback }' <<< "$report"
}

xfce_plasma_performance_geometry() {
  local report width height monitors
  if [ -n "${XFCE_PLASMA_DESKTOP_WIDTH:-}" ] && [ -n "${XFCE_PLASMA_DESKTOP_HEIGHT:-}" ]; then
    printf '%s %s %s\n' "$XFCE_PLASMA_DESKTOP_WIDTH" "$XFCE_PLASMA_DESKTOP_HEIGHT" "${XFCE_PLASMA_MONITOR_COUNT:-1}"
    return
  fi
  report=$(xrandr --current 2>/dev/null || true)
  read -r width height < <(sed -n 's/.*current[[:space:]]\+\([0-9]\+\)[[:space:]]\+x[[:space:]]\+\([0-9]\+\).*/\1 \2/p' <<< "$report" | sed -n '1p')
  monitors=$(awk '/ connected([[:space:]]|$)/ { count++ } END { print count+0 }' <<< "$report")
  printf '%s %s %s\n' "${width:-0}" "${height:-0}" "${monitors:-0}"
}

xfce_plasma_performance_detect() {
  local force=${1:-false} mode report vendor renderer version width height monitors pixels software=false
  local fingerprint cached_fingerprint cached_mode tier reason fps scale now data
  xfce_plasma_mkdirs
  mode=$(xfce_plasma_performance_mode)
  report=${XFCE_PLASMA_GLXINFO_REPORT:-}
  if [ -z "$report" ] && command -v glxinfo >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    report=$(glxinfo -B 2>/dev/null || true)
  fi
  vendor=${XFCE_PLASMA_GL_VENDOR:-$(xfce_plasma_performance_gl_field 'OpenGL vendor string' unknown "$report")}
  renderer=${XFCE_PLASMA_GL_RENDERER:-$(xfce_plasma_performance_gl_field 'OpenGL renderer string' unknown "$report")}
  version=${XFCE_PLASMA_GL_VERSION:-$(xfce_plasma_performance_gl_field 'OpenGL core profile version string' '' "$report")}
  [ -n "$version" ] || version=$(xfce_plasma_performance_gl_field 'OpenGL version string' unknown "$report")
  read -r width height monitors < <(xfce_plasma_performance_geometry)
  case "$width:$height:$monitors" in *[!0-9:]*|'0:'*|*':0:'*|*':0') width=0; height=0; monitors=0 ;; esac
  pixels=$((width * height))
  case "${renderer,,} ${vendor,,}" in *llvmpipe*|*softpipe*|*swrast*|*software\ rasterizer*) software=true ;; esac
  fingerprint=$(printf '%s\n' "$vendor|$renderer|$version|$width|$height|$monitors" | cksum | awk '{print $1}')
  cached_fingerprint=$(xfce_plasma_config_get "$XFCE_PLASMA_PERFORMANCE_PROFILE_FILE" fingerprint 2>/dev/null || true)
  cached_mode=$(xfce_plasma_config_get "$XFCE_PLASMA_PERFORMANCE_PROFILE_FILE" mode 2>/dev/null || true)
  if [ "$force" != true ] && [ "$cached_fingerprint" = "$fingerprint" ] && [ "$cached_mode" = "$mode" ]; then
    cat "$XFCE_PLASMA_PERFORMANCE_PROFILE_FILE"
    return
  fi

  if [ "$mode" != automatic ]; then
    tier=$mode
    reason='manual override'
  elif [ "$software" = true ]; then
    tier=low
    reason='software OpenGL renderer detected'
  elif [ "$pixels" -ge 6000000 ]; then
    tier=low
    reason='high desktop pixel count'
  elif [ "$renderer" = unknown ] || [ "$pixels" -eq 0 ]; then
    tier=balanced
    reason='incomplete hardware detection'
  elif [ "$pixels" -le 4608000 ]; then
    tier=high
    reason='hardware OpenGL at moderate desktop resolution'
  else
    tier=balanced
    reason='hardware OpenGL at multi-monitor resolution'
  fi
  case "$tier" in
    low) fps=20; scale=0.5 ;;
    balanced) fps=30; scale=0.75 ;;
    high) fps=60; scale=1.0 ;;
  esac
  now=${XFCE_PLASMA_PROFILE_NOW:-$(date -Is)}
  data=$(printf 'mode=%s\ntier=%s\nreason=%s\nfps=%s\nrender_scale=%s\nhwdec=auto-safe\nvendor=%s\nrenderer=%s\nopengl_version=%s\ndesktop=%sx%s\nmonitor_count=%s\npixel_count=%s\nsoftware=%s\nfingerprint=%s\ndetected_at=%s\n' \
    "$mode" "$tier" "$reason" "$fps" "$scale" "$vendor" "$renderer" "$version" \
    "$width" "$height" "$monitors" "$pixels" "$software" "$fingerprint" "$now")
  xfce_plasma_atomic_write "$XFCE_PLASMA_PERFORMANCE_PROFILE_FILE" "$data"
  printf '%s\n' "$data"
}

xfce_plasma_performance_export() {
  local profile
  profile=$(xfce_plasma_performance_detect)
  WALLPAPER_FPS=$(xfce_plasma_config_get /dev/stdin fps <<< "$profile")
  WALLPAPER_RENDER_SCALE=$(xfce_plasma_config_get /dev/stdin render_scale <<< "$profile")
  XFCE_PLASMA_PERFORMANCE_TIER=$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")
  export WALLPAPER_FPS WALLPAPER_RENDER_SCALE XFCE_PLASMA_PERFORMANCE_TIER
}
