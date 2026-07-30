#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HOME="$tmp/home"
XDG_STATE_HOME="$tmp/state"
prefix="$tmp/prefix"
mock_bin="$tmp/mock-bin"
settings_log="$tmp/settings.log"
mkdir -p "$HOME" "$XDG_STATE_HOME" "$prefix/bin" "$mock_bin"

cat > "$mock_bin/systemctl" <<'MOCK'
#!/usr/bin/env sh
case "$*" in
  *is-active*) printf 'active\n';;
  *) printf 'systemctl %s\n' "$*" >> "$SETTINGS_LOG";;
esac
MOCK
cat > "$mock_bin/systemd-run" <<'MOCK'
#!/usr/bin/env sh
printf 'systemd-run %s\n' "$*" >> "$SETTINGS_LOG"
MOCK
cat > "$mock_bin/xrandr" <<'MOCK'
#!/usr/bin/env sh
printf 'DP-0 connected primary 1920x1080\nHDMI-0 connected 1920x1080\n'
MOCK
chmod +x "$mock_bin/systemctl" "$mock_bin/systemd-run" "$mock_bin/xrandr"

cat > "$prefix/bin/animated-wallpaper-picker" <<'MOCK'
#!/usr/bin/env sh
case "${1:-}" in
  current) printf 'plasma-lava.fs\n';;
  list) printf 'plasma-lava.fs\nbasic-gradient.fs\n';;
  *) printf 'wallpaper %s\n' "$*" >> "$SETTINGS_LOG";;
esac
MOCK
cat > "$prefix/bin/animated-wallpaper-speed" <<'MOCK'
#!/usr/bin/env sh
case "${1:-}" in current) printf 'medium\n';; *) printf 'speed %s\n' "$*" >> "$SETTINGS_LOG";; esac
MOCK
cat > "$prefix/bin/dual-monitor-wallpaper-sync" <<'MOCK'
#!/usr/bin/env sh
printf 'monitor %s\n' "$*" >> "$SETTINGS_LOG"
MOCK
cat > "$prefix/bin/start-transparent-xfdesktop-session" <<'MOCK'
#!/usr/bin/env sh
printf 'recover\n' >> "$SETTINGS_LOG"
MOCK
cat > "$prefix/bin/start-picom-effects" <<'MOCK'
#!/usr/bin/env sh
exit 0
MOCK
cat > "$prefix/bin/xfce-plasma-doctor" <<'MOCK'
#!/usr/bin/env sh
printf 'doctor ok\n'
MOCK
chmod +x "$prefix/bin/"*

export HOME XDG_STATE_HOME SETTINGS_LOG="$settings_log" XFCE_PLASMA_PREFIX="$prefix"
export PATH="$mock_bin:$PATH"
settings="$repo_root/bin/xfce-plasma-settings"

[ "$($settings wallpaper current)" = "plasma-lava.fs" ]
[ "$($settings speed current)" = "medium" ]
[ "$($settings game status)" = "active" ]
[ "$($settings picom status)" = "active" ]
[ "$($settings desktop status)" = "active" ]
[ "$($settings monitors status)" = "2 connected" ]
[ "$($settings diagnostics)" = "doctor ok" ]
$settings wallpaper set basic-gradient.fs
$settings speed fast
$settings game start
$settings monitors sync
$settings recover
XFCE_PLASMA_SETTINGS_UI=/usr/bin/true "$settings" gui

grep -qx 'wallpaper set basic-gradient.fs' "$settings_log"
grep -qx 'speed fast' "$settings_log"
grep -qx 'systemctl --user enable --now game-mode-guard.service' "$settings_log"
grep -qx 'monitor --once' "$settings_log"
grep -qx 'recover' "$settings_log"
expected_version=$(sed -n '1p' "$repo_root/VERSION")
[ "$($repo_root/build/xfce-plasma-settings-ui --version)" = "xfce-plasma-settings-ui $expected_version" ]
[ "$($repo_root/build/xfce-plasma-renderer --version)" = "xfce-plasma-renderer $expected_version" ]
grep -q 'Background collection — shaders featured' "$repo_root/src/settings/main.c"
grep -q 'Add muted video' "$repo_root/src/settings/main.c"

printf 'test-settings ok\n'
