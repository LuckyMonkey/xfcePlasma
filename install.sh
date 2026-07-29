#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOME_DIR=${HOME:?HOME is required}
USER_NAME=$(id -un)
action=install
dry_run=false
no_enable=false
usage() { printf "usage: %s [--user] [--check] [--dry-run] [--no-enable] [--uninstall]\n" "${0##*/}"; }
check_dependencies() { local name missing=0; for name in bash cp rsync find systemctl xwinwrap xfconf-query; do if command -v "$name" >/dev/null 2>&1; then printf "ok  %s\n" "$name"; else printf "missing  %s\n" "$name"; missing=1; fi; done; return "$missing"; }
while [ "$#" -gt 0 ]; do case "$1" in --user) ;; --check) action=check ;; --dry-run) dry_run=true ;; --no-enable) no_enable=true ;; --uninstall) action=uninstall ;; -h|--help) usage; exit 0 ;; *) printf "unknown option: %s\n" "$1" >&2; usage >&2; exit 2 ;; esac; shift; done
if [ "$action" = check ]; then check_dependencies; exit $?; fi
if [ "$dry_run" = true ]; then printf "Would install xfcePlasma for %s\n  binaries: %s/.local/bin\n  runtime:  %s/.local/lib/tie-dye-wallpaper\n  config:   %s/.config\n  services: %s/.config/systemd/user\n" "$USER_NAME" "$HOME_DIR" "$HOME_DIR" "$HOME_DIR" "$HOME_DIR"; [ "$no_enable" = false ] || printf "  services will not be enabled\n"; exit 0; fi
STATE_DIR=${XDG_STATE_HOME:-$HOME_DIR/.local/state}/xfce-plasma
MANIFEST=$STATE_DIR/install-manifest
if [ "$action" = uninstall ]; then
  [ -r "$MANIFEST" ] || { printf "No xfcePlasma install manifest found: %s\n" "$MANIFEST" >&2; exit 1; }
  systemctl --user disable --now game-mode-guard.service tie-dye-wallpaper-mvp.service xfdesktop-transparent.service >/dev/null 2>&1 || true
  while IFS= read -r path; do [ -n "$path" ] || continue; case "$path" in "$HOME_DIR"/*) case "$path" in */../*|*/..) printf "Refusing non-normal manifest path: %s\n" "$path" >&2; exit 1 ;; *) rm -f -- "$path" ;; esac ;; *) printf "Refusing manifest path outside HOME: %s\n" "$path" >&2; exit 1 ;; esac; done < "$MANIFEST"
  rm -f -- "$MANIFEST"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  printf "Uninstalled project-owned xfcePlasma files; user configuration and user shaders were preserved.\n"
  exit 0
fi
mkdir -p "$STATE_DIR"
manifest_tmp=$(mktemp "$STATE_DIR/.install-manifest.XXXXXX")
trap 'rm -f "$manifest_tmp"' EXIT
record_file() { printf "%s\n" "$1" >> "$manifest_tmp"; }

install_text() {
  src=$1
  dest=$2
  cp -a "$src" "$dest"
  chmod --reference="$src" "$dest" 2>/dev/null || chmod 0644 "$dest"
  record_file "$dest"
}

install_user_config() {
  src=$1
  dest=$2
  if [ ! -e "$dest" ]; then cp -a "$src" "$dest"; fi
}

install_bin_text() {
  src=$1
  dest="$HOME_DIR/.local/bin/$(basename "$src")"
  install_text "$src" "$dest"
  chmod 0755 "$dest"
}

mkdir -p \
  "$HOME_DIR/.local/bin" \
  "$HOME_DIR/.local/lib/tie-dye-wallpaper" \
  "$HOME_DIR/.local/lib/xfce-plasma" \
  "$HOME_DIR/.local/opt/xfdesktop-transparent" \
  "$HOME_DIR/.local/share/applications" \
  "$HOME_DIR/.config/picom" \
  "$HOME_DIR/.config/game-mode-guard" \
  "$HOME_DIR/.config/autostart" \
  "$HOME_DIR/.config/systemd/user"

cp -a "$ROOT/lib/xfce-plasma-common.sh" "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-common.sh"
chmod 0644 "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-common.sh"
record_file "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-common.sh"

cp -a "$ROOT/runtime/xfce-plasma-settings-ui" "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-settings-ui"
chmod 0755 "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-settings-ui"
record_file "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-settings-ui"

for script in \
  tie-dye-wallpaper \
  restart-animated-wallpaper-renderer \
  start-picom-effects \
  stop-animated-wallpaper \
  dual-monitor-wallpaper-sync \
  game-mode-guard \
  game-mode-raster-wallpaper \
  game-mode-fade \
  animated-wallpaper-picker \
  animated-wallpaper-speed \
  xfce-plasma-doctor \
  xfce-plasma-settings \
  start-animated-wallpaper-with-xfdesktop-icons \
  start-transparent-xfdesktop-session \
  run-custom-xfdesktop \
  stop-custom-xfdesktop \
  restore-packaged-xfdesktop \
  raise-floating-whisker; do
  install_bin_text "$ROOT/bin/$script"
done

cp -a "$ROOT/runtime/tie-dye-wallpaper/tie-dye-wallpaper" "$HOME_DIR/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper"
cp -a "$ROOT/runtime/tie-dye-wallpaper/shader.fs" "$HOME_DIR/.local/lib/tie-dye-wallpaper/shader.fs"
rsync -a "$ROOT/runtime/tie-dye-wallpaper/shaders/" "$HOME_DIR/.local/lib/tie-dye-wallpaper/shaders/"
retired_shader_dir="$HOME_DIR/.local/state/xfce-plasma/retired-shaders"
for retired_shader in isometric-city.fs trippy-houndstooth.fs; do
  if [ -f "$HOME_DIR/.local/lib/tie-dye-wallpaper/shaders/$retired_shader" ]; then
    mkdir -p "$retired_shader_dir"
    mv -f "$HOME_DIR/.local/lib/tie-dye-wallpaper/shaders/$retired_shader" "$retired_shader_dir/$retired_shader"
  fi
done
chmod 0755 "$HOME_DIR/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper"
record_file "$HOME_DIR/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper"
record_file "$HOME_DIR/.local/lib/tie-dye-wallpaper/shader.fs"
while IFS= read -r source_file; do record_file "$HOME_DIR/.local/lib/tie-dye-wallpaper/shaders/${source_file#"$ROOT/runtime/tie-dye-wallpaper/shaders/"}"; done < <(find "$ROOT/runtime/tie-dye-wallpaper/shaders" -type f)

cp -a "$ROOT/runtime/picom-v13" "$HOME_DIR/.local/bin/picom"
chmod 0755 "$HOME_DIR/.local/bin/picom"
record_file "$HOME_DIR/.local/bin/picom"

rsync -a "$ROOT/runtime/xfdesktop-transparent/" "$HOME_DIR/.local/opt/xfdesktop-transparent/"
find "$HOME_DIR/.local/opt/xfdesktop-transparent/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
while IFS= read -r source_file; do record_file "$HOME_DIR/.local/opt/xfdesktop-transparent/${source_file#"$ROOT/runtime/xfdesktop-transparent/"}"; done < <(find "$ROOT/runtime/xfdesktop-transparent" -type f)

install_user_config "$ROOT/config/picom/picom.conf" "$HOME_DIR/.config/picom/picom.conf"
install_user_config "$ROOT/config/game-mode-guard/patterns" "$HOME_DIR/.config/game-mode-guard/patterns"

for application in "$ROOT"/applications/*.desktop; do
  install_text "$application" "$HOME_DIR/.local/share/applications/$(basename "$application")"
done

for desktop in "$ROOT"/autostart/*.desktop; do
  install_text "$desktop" "$HOME_DIR/.config/autostart/$(basename "$desktop")"
done

for service in "$ROOT"/systemd/user/*.service; do
  install_text "$service" "$HOME_DIR/.config/systemd/user/$(basename "$service")"
done

sort -u "$manifest_tmp" -o "$manifest_tmp"
mv -f "$manifest_tmp" "$MANIFEST"

systemctl --user daemon-reload || true

echo "Installed xfcePlasma files for $USER_NAME."
echo "Recommended next steps:"
echo "  systemctl --user enable --now game-mode-guard.service"
echo "  systemctl --user restart tie-dye-wallpaper-mvp.service"
echo "  ~/.local/bin/start-animated-wallpaper-with-xfdesktop-icons"
