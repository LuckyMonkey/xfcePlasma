#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home
export XDG_CONFIG_HOME=$tmp/config XDG_DATA_HOME=$tmp/data XDG_STATE_HOME=$tmp/state
export XDG_CACHE_HOME=$tmp/cache XDG_RUNTIME_DIR=$tmp/run
export XFCE_PLASMA_RENDERER_DIR="$tmp/Renderer With Spaces"
export WALLPAPER_RUNTIME=$XFCE_PLASMA_RENDERER_DIR
export XFCE_PLASMA_BACKGROUND_UNIT=test-background.service
export SYSTEMCTL_LOG=$tmp/systemctl.log XWINWRAP_LOG=$tmp/xwinwrap.log
export RENDERER_LOG=$tmp/renderer.log XFCONF_LOG=$tmp/xfconf.log
mock_bin=$tmp/bin
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$mock_bin" "$XFCE_PLASMA_RENDERER_DIR/shaders"

cp "$repo_root/runtime/tie-dye-wallpaper/shaders/plasma.fs" "$XFCE_PLASMA_RENDERER_DIR/shaders/plasma.fs"
cp "$repo_root/runtime/tie-dye-wallpaper/shaders/plasma.fs" "$XFCE_PLASMA_RENDERER_DIR/shader.fs"

cat > "$mock_bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
case "$*" in
  '--user is-active --quiet '*) exit "${SYSTEMCTL_ACTIVE:-1}" ;;
  '--user is-active '*) printf 'active\n' ;;
esac
exit 0
MOCK
cat > "$mock_bin/xfconf-query" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$XFCONF_LOG"
MOCK
cat > "$mock_bin/xwinwrap" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$XWINWRAP_LOG"
while [ "$#" -gt 0 ] && [ "$1" != -- ]; do shift; done
[ "$#" -gt 0 ] && shift
command=()
for argument in "$@"; do
  if [ "$argument" = WID ]; then command+=(0x123abc); else command+=("$argument"); fi
done
exec "${command[@]}"
MOCK
cat > "$XFCE_PLASMA_RENDERER_DIR/tie-dye-wallpaper" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RENDERER_LOG"
MOCK
chmod 0755 "$mock_bin"/* "$XFCE_PLASMA_RENDERER_DIR/tie-dye-wallpaper"
export PATH=$mock_bin:$PATH XFCE_PLASMA_XWINWRAP=$mock_bin/xwinwrap

background=$repo_root/bin/xfce-plasma-background
"$background" migrate >/dev/null
grep -qx 'type=shader' "$XDG_STATE_HOME/xfce-plasma/active-source"
grep -qx 'id=plasma' "$XDG_STATE_HOME/xfce-plasma/active-source"

SYSTEMCTL_ACTIVE=1 "$background" shader tie-dye.fs >/dev/null
grep -qx 'plasma.fs' "$XDG_STATE_HOME/tie-dye-wallpaper/current-shader"
grep -qx 'id=plasma' "$XDG_STATE_HOME/xfce-plasma/active-source"
if grep -q 'restart test-background.service' "$SYSTEMCTL_LOG"; then
  printf 'shader hot reload unnecessarily restarted the background service\n' >&2
  exit 1
fi

"$background" run
grep -qx -- '--wid 0x123abc' "$RENDERER_LOG"
grep -qx 'type=shader' "$XDG_RUNTIME_DIR/xfce-plasma/backend.state"
grep -qx 'backend=raylib' "$XDG_RUNTIME_DIR/xfce-plasma/backend.state"
grep -qx 'window_id=0x123abc' "$XDG_RUNTIME_DIR/xfce-plasma/backend.state"

"$background" pause
grep -qx paused "$XDG_RUNTIME_DIR/xfce-plasma/backend.status"
"$background" resume
grep -qx running "$XDG_RUNTIME_DIR/xfce-plasma/backend.status"
grep -q -- '--signal=STOP test-background.service' "$SYSTEMCTL_LOG"
grep -q -- '--signal=CONT test-background.service' "$SYSTEMCTL_LOG"

report=$("$background" status)
case "$report" in *'source_type=shader'*'source_id=plasma'*'backend=raylib'*'window_id=0x123abc'*) ;; *) printf 'incomplete background status\n%s\n' "$report" >&2; exit 1 ;; esac

"$background" stop
[ ! -e "$XDG_RUNTIME_DIR/xfce-plasma/backend.state" ]
if rg -n 'pkill|killall|pkill -f' "$repo_root/bin/xfce-plasma-background" "$repo_root/bin/stop-animated-wallpaper"; then
  printf 'background lifecycle contains broad process killing\n' >&2
  exit 1
fi
printf 'test-background ok\n'
