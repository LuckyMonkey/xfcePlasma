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
[ -x "$test_home/.local/bin/restart-animated-wallpaper-renderer" ]
[ -x "$test_home/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper" ]
[ -f "$test_home/.config/systemd/user/tie-dye-wallpaper-mvp.service" ]
[ -f "$test_home/.config/autostart/tie-dye-wallpaper.desktop" ]

pattern_file="$tmp/personal-patterns"
{
  printf "/home/%s\n" "freezer"
  printf "/run/user/%s\n" "1000"
  printf "USER=%s\n" "freezer"
  printf "LOGNAME=%s\n" "freezer"
  printf "DISPLAY=:%s[.]%s\n" "0" "0"
} > "$pattern_file"
if rg -n -f "$pattern_file" "$test_home/.local/bin" "$test_home/.config/systemd/user" "$test_home/.config/autostart"; then
  printf "installed runtime contains a personal path\n" >&2
  exit 1
fi

printf "keep=true\n" > "$test_home/.config/picom/user-kept.conf"
printf "user shader\n" > "$test_home/.local/lib/tie-dye-wallpaper/shaders/user-kept.fs"
[ -s "$test_home/.local/state/xfce-plasma/install-manifest" ]
HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null
[ ! -e "$test_home/.local/bin/animated-wallpaper-picker" ]
[ ! -e "$test_home/.local/lib/tie-dye-wallpaper/shaders/tie-dye.fs" ]
[ -e "$test_home/.local/lib/tie-dye-wallpaper/shaders/user-kept.fs" ]
[ -e "$test_home/.config/picom/picom.conf" ]
[ -e "$test_home/.config/picom/user-kept.conf" ]
[ ! -e "$test_home/.local/state/xfce-plasma/install-manifest" ]
HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --user --no-enable >/dev/null
outside_marker="$tmp/outside-kept"
printf "keep\n" > "$outside_marker"
printf "%s\n" "$test_home/../outside-kept" > "$test_home/.local/state/xfce-plasma/install-manifest"
if HOME="$test_home" PATH="$test_bin:$PATH" "$repo_root/install.sh" --uninstall >/dev/null 2>&1; then printf "unsafe manifest path was accepted\n" >&2; exit 1; fi
[ -e "$outside_marker" ]
printf "test-installer-dry-run ok\n"
