#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
HOME=$tmp/home
XDG_CONFIG_HOME=$HOME/config
XDG_DATA_HOME=$HOME/data
XDG_STATE_HOME=$HOME/state
XDG_CACHE_HOME=$HOME/cache
prefix=$HOME/.local
mock_bin=$tmp/bin
mkdir -p "$prefix/lib/tie-dye-wallpaper/shaders" "$prefix/lib/xfce-plasma" \
  "$prefix/opt/xfdesktop-transparent/bin" "$prefix/bin" "$XDG_CONFIG_HOME" \
  "$XDG_DATA_HOME" "$XDG_STATE_HOME/tie-dye-wallpaper" "$XDG_CACHE_HOME" "$mock_bin"
cp "$repo_root/build/xfce-plasma-renderer" "$prefix/lib/tie-dye-wallpaper/tie-dye-wallpaper"
cp "$repo_root/build/xfce-plasma-settings-ui" "$prefix/lib/xfce-plasma/xfce-plasma-settings-ui"
cp /usr/bin/true "$prefix/opt/xfdesktop-transparent/bin/xfdesktop"
cp /usr/bin/true "$prefix/bin/picom"
cp "$repo_root/VERSION" "$prefix/lib/xfce-plasma/VERSION"
printf 'built-from-source\n' > "$prefix/lib/xfce-plasma/install-origin"
printf '#version 330\n' > "$prefix/lib/tie-dye-wallpaper/shaders/test.fs"
printf '#version 330\n' > "$prefix/lib/tie-dye-wallpaper/shader.fs"
printf 'test.fs\n' > "$XDG_STATE_HOME/tie-dye-wallpaper/current-shader"
printf 'cookie\n' > "$HOME/.Xauthority"

cat > "$mock_bin/systemctl" <<'MOCK'
#!/usr/bin/env sh
case "$*" in
  '--user show-environment'|--user\ cat\ *|--user\ is-enabled\ --quiet\ *|--user\ is-active\ --quiet\ *) exit 0 ;;
  *) exit 0 ;;
esac
MOCK
cat > "$mock_bin/xrandr" <<'MOCK'
#!/usr/bin/env sh
printf 'Virtual-1 connected 1280x720\n'
MOCK
cat > "$mock_bin/pgrep" <<'MOCK'
#!/usr/bin/env sh
case "$*" in -fc\ *|-xc\ *) printf '1\n';; *) exit 1;; esac
MOCK
chmod 0755 "$mock_bin/systemctl" "$mock_bin/xrandr" "$mock_bin/pgrep"
for command_name in xwinwrap xfconf-query xprop import convert xdotool wmctrl notify-send zenity; do
  ln -s /usr/bin/true "$mock_bin/$command_name"
done

export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
export DISPLAY=:77 XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=XFCE XAUTHORITY=$HOME/.Xauthority
export PATH=$mock_bin:$PATH

doctor=$repo_root/bin/xfce-plasma-doctor
report=$($doctor --project-root "$repo_root")
case "$report" in
  *'Project version: '*'Install origin: built-from-source'*'OK        renderer runs and reports'*'Result: 0 error(s)'*) ;;
  *) printf 'healthy doctor report was incomplete\n%s\n' "$report" >&2; exit 1 ;;
esac

rm "$prefix/lib/tie-dye-wallpaper/shader.fs"
if failure_report=$($doctor --project-root "$repo_root" 2>&1); then
  printf 'doctor accepted a missing active shader\n' >&2
  exit 1
fi
case "$failure_report" in
  *'ERROR     active shader is missing or unreadable:'*'Fix: Select a shader'*) ;;
  *) printf 'missing shader lacked an actionable error\n%s\n' "$failure_report" >&2; exit 1 ;;
esac

printf '#version 330\n' > "$prefix/lib/tie-dye-wallpaper/shader.fs"
if wayland_report=$(XDG_SESSION_TYPE=wayland $doctor --project-root "$repo_root" 2>&1); then
  printf 'doctor claimed Wayland support\n' >&2
  exit 1
fi
case "$wayland_report" in
  *'ERROR     session type is Wayland; xfcePlasma does not support Wayland'*'Fix: Log into an XFCE X11 session.'*) ;;
  *) printf 'Wayland error was not explicit\n%s\n' "$wayland_report" >&2; exit 1 ;;
esac

printf 'test-doctor ok\n'
