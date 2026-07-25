#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HOME="$tmp/home"
XDG_STATE_HOME="$tmp/state"
XDG_CACHE_HOME="$tmp/cache"
XDG_DATA_HOME="$tmp/data"
XDG_CONFIG_HOME="$tmp/config"
runtime="$tmp/runtime with spaces"
mock_bin="$tmp/bin"
mkdir -p "$HOME" "$runtime/shaders" "$mock_bin" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

cat > "$mock_bin/systemctl" <<'MOCK'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
exit 0
MOCK
chmod +x "$mock_bin/systemctl"

cat > "$mock_bin/notify-send" <<'MOCK'
#!/usr/bin/env sh
exit 0
MOCK
chmod +x "$mock_bin/notify-send"

printf 'shader one\n' > "$runtime/shaders/tie-dye.fs"
printf 'shader two\n' > "$runtime/shaders/motion-halftone.fs"
printf 'shader custom\n' > "$runtime/shaders/custom space.fs"
printf 'shader one\n' > "$runtime/shader.fs"

SYSTEMCTL_LOG="$tmp/systemctl.log"
PATH="$mock_bin:$PATH"
export HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_CONFIG_HOME SYSTEMCTL_LOG PATH
export WALLPAPER_RUNTIME="$runtime"

list=$("$repo_root/bin/animated-wallpaper-picker" list)
case "$list" in
  *tie-dye.fs*motion-halftone.fs*'custom space.fs'*) ;;
  *) echo "unexpected list: $list" >&2; exit 1;;
esac

current=$("$repo_root/bin/animated-wallpaper-picker" current)
[ "$current" = "tie-dye.fs" ]

"$repo_root/bin/animated-wallpaper-picker" set 'custom space.fs'
[ "$(cat "$runtime/shader.fs")" = "shader custom" ]
[ "$(cat "$XDG_STATE_HOME/tie-dye-wallpaper/current-shader")" = "custom space.fs" ]
[ "$(grep -c 'restart tie-dye-wallpaper-mvp.service' "$SYSTEMCTL_LOG")" -eq 1 ]
[ "$(grep -c 'restart xfdesktop-transparent.service' "$SYSTEMCTL_LOG")" -eq 1 ]

next=$("$repo_root/bin/animated-wallpaper-picker" next; cat "$XDG_STATE_HOME/tie-dye-wallpaper/current-shader")
case "$next" in
  *tie-dye.fs) ;;
  *) echo "unexpected next state: $next" >&2; exit 1;;
esac

printf 'test-picker ok\n'
