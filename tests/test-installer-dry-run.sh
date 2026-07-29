#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

test_home="$tmp/Home With Spaces"
test_bin="$tmp/bin"
mkdir -p "$test_home" "$test_bin"
ln -s /usr/bin/true "$test_bin/systemctl"

dry_output=$(HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --dry-run)
case "$dry_output" in *"$test_home/.local/bin"*) ;; *) printf "dry-run omitted target home\n" >&2; exit 1 ;; esac
[ ! -e "$test_home/.local" ]
[ ! -e "$test_home/.config" ]

HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable >/dev/null
[ -x "$test_home/.local/bin/animated-wallpaper-picker" ]
[ -x "$test_home/.local/bin/xfce-plasma-doctor" ]
[ -x "$test_home/.local/bin/xfce-plasma-settings" ]
[ -x "$test_home/.local/lib/xfce-plasma/xfce-plasma-settings-ui" ]
[ -f "$test_home/.local/share/applications/xfce-plasma-settings.desktop" ]
[ -x "$test_home/.local/bin/restart-animated-wallpaper-renderer" ]
[ -f "$test_home/.local/share/xfce-plasma/assets/thumbnails/tie-dye.png" ]
[ -f "$test_home/.local/share/icons/hicolor/scalable/apps/xfce-plasma.svg" ]
[ -f "$test_home/.local/lib/tie-dye-wallpaper/shaders/tie-dye.meta" ]
[ -x "$test_home/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper" ]
cmp -s "$repo_root/build/xfce-plasma-renderer" "$test_home/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper"
cmp -s "$repo_root/build/xfce-plasma-settings-ui" "$test_home/.local/lib/xfce-plasma/xfce-plasma-settings-ui"
expected_version=$(sed -n '1p' "$repo_root/VERSION")
[ "$("$test_home/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper" --version)" = "xfce-plasma-renderer $expected_version" ]
[ "$("$test_home/.local/lib/xfce-plasma/xfce-plasma-settings-ui" --version)" = "xfce-plasma-settings-ui $expected_version" ]
[ "$(sed -n '1p' "$test_home/.local/lib/xfce-plasma/install-origin")" = built-from-source ]
version_report=$(HOME="$test_home" XDG_STATE_HOME="$test_home/.local/state" "$test_home/.local/bin/xfce-plasma-settings" version)
case "$version_report" in *"project version: $expected_version"*"install origin: built-from-source"*) ;; *) printf 'installed version report is incomplete\n%s\n' "$version_report" >&2; exit 1 ;; esac
doctor_report=$(HOME="$test_home" XDG_STATE_HOME="$test_home/.local/state" PATH="$test_bin:$PATH" "$test_home/.local/bin/xfce-plasma-doctor" --project-root "$repo_root" 2>&1 || true)
case "$doctor_report" in *"Project version: $expected_version"*"Install origin: built-from-source"*"xfce-plasma-renderer $expected_version"*"xfce-plasma-settings-ui $expected_version"*) ;; *) printf 'doctor version report is incomplete\n%s\n' "$doctor_report" >&2; exit 1 ;; esac
[ -f "$test_home/.config/systemd/user/tie-dye-wallpaper-mvp.service" ]
[ -f "$test_home/.config/autostart/tie-dye-wallpaper.desktop" ]
if grep -q '^WantedBy=default.target$' \
  "$test_home/.config/systemd/user/tie-dye-wallpaper-mvp.service" \
  "$test_home/.config/systemd/user/xfdesktop-transparent.service"; then
  printf "desktop stack services must be owned by XFCE autostart\n" >&2
  exit 1
fi
grep -q '^X-GNOME-Autostart-enabled=true$' "$test_home/.config/autostart/tie-dye-wallpaper.desktop"

pattern_file="$tmp/personal-patterns"
{
  printf "/home/%s\n" "freezer"
  printf "/run/user/%s\n" "1000"
  printf "USER=%s\n" "freezer"
  printf "LOGNAME=%s\n" "freezer"
  printf "DISPLAY=:%s[.]%s\n" "0" "0"
} > "$pattern_file"
if rg -n -f "$pattern_file" "$test_home/.local/bin" "$test_home/.config/systemd/user" "$test_home/.config/autostart" "$test_home/.local/share/applications"; then
  printf "installed runtime contains a personal path\n" >&2
  exit 1
fi

printf "keep=true\n" > "$test_home/.config/picom/user-kept.conf"
printf "user shader\n" > "$test_home/.local/lib/tie-dye-wallpaper/shaders/user-kept.fs"
mkdir -p "$test_home/.local/share/xfce-plasma/user-shaders"
printf "user data shader\n" > "$test_home/.local/share/xfce-plasma/user-shaders/user-data-kept.fs"
printf "custom picom configuration\n" > "$test_home/.config/picom/picom.conf"
printf "custom active shader\n" > "$test_home/.local/lib/tie-dye-wallpaper/shader.fs"
obsolete_file="$test_home/.local/bin/xfce-plasma-obsolete-helper"
printf "obsolete project helper\n" > "$obsolete_file"
printf "%s\n" "$obsolete_file" >> "$test_home/.local/state/xfce-plasma/install-manifest"
sort -u -o "$test_home/.local/state/xfce-plasma/install-manifest" "$test_home/.local/state/xfce-plasma/install-manifest"
upgrade_dry_output=$(HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --dry-run)
case "$upgrade_dry_output" in *"obsolete project files to remove:"*"$obsolete_file"*) ;; *) printf "dry-run omitted obsolete upgrade file\n" >&2; exit 1 ;; esac
[ -e "$obsolete_file" ]
grep -qx "custom picom configuration" "$test_home/.config/picom/picom.conf"
grep -qx "custom active shader" "$test_home/.local/lib/tie-dye-wallpaper/shader.fs"
HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable >/dev/null
[ ! -e "$obsolete_file" ]
grep -qx "custom picom configuration" "$test_home/.config/picom/picom.conf"
grep -qx "custom active shader" "$test_home/.local/lib/tie-dye-wallpaper/shader.fs"
[ -e "$test_home/.local/lib/tie-dye-wallpaper/shaders/user-kept.fs" ]
[ -e "$test_home/.local/share/xfce-plasma/user-shaders/user-data-kept.fs" ]
printf "user state\n" > "$test_home/.local/state/xfce-plasma/user-state-kept"
mkdir -p "$test_home/.local/state/tie-dye-wallpaper"
printf "user-data-kept.fs\n" > "$test_home/.local/state/tie-dye-wallpaper/current-shader"
HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable >/dev/null
cmp -s "$test_home/.local/share/xfce-plasma/user-shaders/user-data-kept.fs" "$test_home/.local/lib/tie-dye-wallpaper/shader.fs"
uninstall_dry_output=$(HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall --dry-run)
case "$uninstall_dry_output" in *"Would uninstall"*"animated-wallpaper-picker"*) ;; *) printf "uninstall dry-run omitted owned files\n" >&2; exit 1 ;; esac
[ -x "$test_home/.local/bin/animated-wallpaper-picker" ]
[ -s "$test_home/.local/state/xfce-plasma/install-manifest" ]
HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null
[ ! -e "$test_home/.local/bin/animated-wallpaper-picker" ]
[ ! -e "$test_home/.local/bin/xfce-plasma-doctor" ]
[ ! -e "$test_home/.local/bin/xfce-plasma-settings" ]
[ ! -e "$test_home/.local/lib/xfce-plasma/xfce-plasma-settings-ui" ]
[ ! -e "$test_home/.local/share/applications/xfce-plasma-settings.desktop" ]
[ ! -e "$test_home/.local/lib/tie-dye-wallpaper/shaders/tie-dye.fs" ]
[ -e "$test_home/.local/lib/tie-dye-wallpaper/shaders/user-kept.fs" ]
[ -e "$test_home/.local/share/xfce-plasma/user-shaders/user-data-kept.fs" ]
[ -e "$test_home/.config/picom/picom.conf" ]
[ -e "$test_home/.config/picom/user-kept.conf" ]
[ -f "$test_home/.local/state/xfce-plasma/user-state-kept" ]
[ -f "$test_home/.local/state/tie-dye-wallpaper/current-shader" ]
[ ! -e "$test_home/.local/state/xfce-plasma/install-manifest" ]
HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable >/dev/null
outside_marker="$tmp/outside-kept"
printf "keep\n" > "$outside_marker"
printf "%s\n" "$test_home/../outside-kept" > "$test_home/.local/state/xfce-plasma/install-manifest"
if HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null 2>&1; then printf "unsafe manifest path was accepted\n" >&2; exit 1; fi
[ -e "$outside_marker" ]

bundled_home="$tmp/Bundled Home"
printf "%s\n\n" "$test_home/.local/bin/animated-wallpaper-picker" > "$test_home/.local/state/xfce-plasma/install-manifest"
if HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null 2>&1; then printf "empty manifest path was accepted\n" >&2; exit 1; fi
sed -i "/^$/d" "$test_home/.local/state/xfce-plasma/install-manifest"
mkdir -p "$bundled_home"
HOME="$bundled_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable --use-bundled-runtime >/dev/null
cmp -s "$repo_root/runtime/tie-dye-wallpaper/tie-dye-wallpaper" "$bundled_home/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper"
cmp -s "$repo_root/runtime/xfce-plasma-settings-ui" "$bundled_home/.local/lib/xfce-plasma/xfce-plasma-settings-ui"
[ "$(sed -n '1p' "$bundled_home/.local/lib/xfce-plasma/install-origin")" = bundled-runtime ]
[ "$("$bundled_home/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper" --version)" = "xfce-plasma-renderer $expected_version" ]
[ "$("$bundled_home/.local/lib/xfce-plasma/xfce-plasma-settings-ui" --version)" = "xfce-plasma-settings-ui $expected_version" ]
HOME="$bundled_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null
malicious_home="$tmp/Symlink Home"
outside_dir="$tmp/outside-bin"
mkdir -p "$malicious_home/.local" "$outside_dir"
ln -s "$outside_dir" "$malicious_home/.local/bin"
if HOME="$malicious_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --dry-run >/dev/null 2>&1; then printf "symlinked install root outside HOME was accepted\n" >&2; exit 1; fi
[ ! -e "$outside_dir/animated-wallpaper-picker" ]
xdg_home="$tmp/XDG Home"
xdg_config="$xdg_home/config-root"
xdg_data="$xdg_home/data-root"
xdg_state="$xdg_home/state-root"
mkdir -p "$xdg_home"
HOME="$xdg_home" XDG_CONFIG_HOME="$xdg_config" XDG_DATA_HOME="$xdg_data" XDG_STATE_HOME="$xdg_state" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable --use-bundled-runtime >/dev/null
[ -f "$xdg_config/systemd/user/tie-dye-wallpaper-mvp.service" ]
[ -f "$xdg_data/applications/xfce-plasma-settings.desktop" ]
[ -s "$xdg_state/xfce-plasma/install-manifest" ]
[ -x "$xdg_home/.local/bin/xfce-plasma-settings" ]
printf "xdg user config\n" > "$xdg_config/picom/picom.conf"
HOME="$xdg_home" XDG_CONFIG_HOME="$xdg_config" XDG_DATA_HOME="$xdg_data" XDG_STATE_HOME="$xdg_state" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null
[ -f "$xdg_config/picom/picom.conf" ]
[ ! -e "$xdg_home/.local/bin/xfce-plasma-settings" ]
printf "test-installer-dry-run ok\n"
