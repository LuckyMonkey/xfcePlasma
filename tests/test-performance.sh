#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_DATA_HOME=$tmp/data
export XDG_STATE_HOME=$tmp/state XDG_CACHE_HOME=$tmp/cache XDG_RUNTIME_DIR=$tmp/run
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
. "$repo_root/lib/xfce-plasma-common.sh"
. "$repo_root/lib/xfce-plasma-performance.sh"

profile_for() {
  rm -f "$XFCE_PLASMA_PERFORMANCE_PROFILE_FILE"
  XFCE_PLASMA_GL_VENDOR=$1 XFCE_PLASMA_GL_RENDERER=$2 XFCE_PLASMA_GL_VERSION=$3 \
    XFCE_PLASMA_DESKTOP_WIDTH=$4 XFCE_PLASMA_DESKTOP_HEIGHT=$5 XFCE_PLASMA_MONITOR_COUNT=${6:-1} \
    xfce_plasma_performance_detect true
}

profile=$(profile_for Mesa llvmpipe 4.5 1920 1080)
[ "$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")" = low ]
[ "$(xfce_plasma_config_get /dev/stdin render_scale <<< "$profile")" = 0.5 ]
profile=$(profile_for unknown unknown unknown 1920 1080)
[ "$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")" = balanced ]
profile=$(profile_for Mesa 'AMD Radeon RX 6600' 4.6 1920 1080)
[ "$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")" = high ]
! grep -qi cuda <<< "$profile"
profile=$(profile_for NVIDIA 'GeForce RTX 3050' 4.6 7680 2160 2)
[ "$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")" = low ]
! grep -qi cuda <<< "$profile"
profile=$(profile_for NVIDIA 'GeForce RTX 3050' 4.6 5760 1080 2)
[ "$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")" = low ]
[ "$(xfce_plasma_config_get /dev/stdin fps <<< "$profile")" = 20 ]

xfce_plasma_performance_set_mode high
profile=$(XFCE_PLASMA_GL_VENDOR=Mesa XFCE_PLASMA_GL_RENDERER=llvmpipe XFCE_PLASMA_GL_VERSION=4.5 \
  XFCE_PLASMA_DESKTOP_WIDTH=7680 XFCE_PLASMA_DESKTOP_HEIGHT=2160 xfce_plasma_performance_detect true)
[ "$(xfce_plasma_config_get /dev/stdin tier <<< "$profile")" = high ]
[ "$(xfce_plasma_config_get /dev/stdin reason <<< "$profile")" = 'manual override' ]

xfce_plasma_performance_set_mode automatic
first=$(XFCE_PLASMA_PROFILE_NOW=first XFCE_PLASMA_GL_VENDOR=Mesa XFCE_PLASMA_GL_RENDERER='Intel UHD' XFCE_PLASMA_GL_VERSION=4.6 \
  XFCE_PLASMA_DESKTOP_WIDTH=1920 XFCE_PLASMA_DESKTOP_HEIGHT=1080 xfce_plasma_performance_detect true)
second=$(XFCE_PLASMA_PROFILE_NOW=second XFCE_PLASMA_GL_VENDOR=Mesa XFCE_PLASMA_GL_RENDERER='Intel UHD' XFCE_PLASMA_GL_VERSION=4.6 \
  XFCE_PLASMA_DESKTOP_WIDTH=1920 XFCE_PLASMA_DESKTOP_HEIGHT=1080 xfce_plasma_performance_detect)
[ "$(xfce_plasma_config_get /dev/stdin detected_at <<< "$first")" = first ]
[ "$(xfce_plasma_config_get /dev/stdin detected_at <<< "$second")" = first ]
printf 'test-performance ok\n'
