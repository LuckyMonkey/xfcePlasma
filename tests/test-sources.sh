#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home
export XDG_CONFIG_HOME=$tmp/config XDG_DATA_HOME=$tmp/data XDG_STATE_HOME=$tmp/state
export XDG_CACHE_HOME=$tmp/cache XDG_RUNTIME_DIR=$tmp/run
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME/tie-dye-wallpaper"

. "$repo_root/lib/xfce-plasma-common.sh"
. "$repo_root/lib/xfce-plasma-sources.sh"

printf 'tie-dye.fs\n' > "$XDG_STATE_HOME/tie-dye-wallpaper/current-shader"
xfce_plasma_source_migrate
[ "$(xfce_plasma_source_active_type)" = shader ]
[ "$(xfce_plasma_source_active_id)" = plasma ]
[ -f "$XDG_STATE_HOME/tie-dye-wallpaper/current-shader" ]
first=$(sha256sum "$XFCE_PLASMA_ACTIVE_SOURCE_FILE")
xfce_plasma_source_migrate
[ "$first" = "$(sha256sum "$XFCE_PLASMA_ACTIVE_SOURCE_FILE")" ]

good=$tmp/good.source
printf 'type=video\nid=my-video\npath=%s\nloop=true\nmuted=true\nfit=cover\n' "$tmp/Video With Spaces.webm" > "$good"
xfce_plasma_source_validate_file "$good"
xfce_plasma_source_write_definition my-video "$(cat "$good")" >/dev/null
xfce_plasma_source_write_active video my-video
xfce_plasma_source_validate_selector "$XFCE_PLASMA_ACTIVE_SOURCE_FILE"
[ "$(xfce_plasma_source_active_config)" = "$XFCE_PLASMA_SOURCE_DIR/my-video.source" ]
printf 'type=unknown\nid=bad\n' > "$tmp/bad-type.source"
! xfce_plasma_source_validate_file "$tmp/bad-type.source" >/dev/null 2>&1
printf 'type=video\nid=bad\npath=relative.webm\n' > "$tmp/bad-path.source"
! xfce_plasma_source_validate_file "$tmp/bad-path.source" >/dev/null 2>&1
printf 'type=shader\nid=ok\nmalicious=$(touch %s)\n' "$tmp/pwned" > "$tmp/malicious.source"
! xfce_plasma_source_validate_file "$tmp/malicious.source" >/dev/null 2>&1
[ ! -e "$tmp/pwned" ]

[ "$(xfce_plasma_redact_url 'rtsp://alice:secret@camera.local/live')" = 'rtsp://***:***@camera.local/live' ]
[ "$(xfce_plasma_redact_url 'rtsp://alice@camera.local/live?token=secret')" = 'rtsp://***:***@camera.local/live?token=***' ]
printf 'test-sources ok\n'
