#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOME_DIR=${HOME:?HOME is required}
USER_NAME=$(id -un)
action=install
dry_run=false
no_enable=false
usage() { printf "usage: %s [--user] [--check] [--dry-run] [--no-enable]\n" "${0##*/}"; }
check_dependencies() { local name missing=0; for name in bash cp rsync find systemctl xwinwrap xfconf-query; do if command -v "$name" >/dev/null 2>&1; then printf "ok  %s\n" "$name"; else printf "missing  %s\n" "$name"; missing=1; fi; done; return "$missing"; }
while [ "$#" -gt 0 ]; do case "$1" in --user) ;; --check) action=check ;; --dry-run) dry_run=true ;; --no-enable) no_enable=true ;; -h|--help) usage; exit 0 ;; *) printf "unknown option: %s\n" "$1" >&2; usage >&2; exit 2 ;; esac; shift; done
if [ "$action" = check ]; then check_dependencies; exit $?; fi
if [ "$dry_run" = true ]; then printf "Would install xfcePlasma for %s\n  binaries: %s/.local/bin\n  runtime:  %s/.local/lib/tie-dye-wallpaper\n  config:   %s/.config\n  services: %s/.config/systemd/user\n" "$USER_NAME" "$HOME_DIR" "$HOME_DIR" "$HOME_DIR" "$HOME_DIR"; [ "$no_enable" = false ] || printf "  services will not be enabled\n"; exit 0; fi

install_text() {
  src=$1
  dest=$2
  cp -a "$src" "$dest"
  chmod --reference="$src" "$dest" 2>/dev/null || chmod 0644 "$dest"
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
  "$HOME_DIR/.config/picom" \
  "$HOME_DIR/.config/game-mode-guard" \
  "$HOME_DIR/.config/autostart" \
  "$HOME_DIR/.config/systemd/user"

cp -a "$ROOT/lib/xfce-plasma-common.sh" "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-common.sh"
chmod 0644 "$HOME_DIR/.local/lib/xfce-plasma/xfce-plasma-common.sh"

for script in \
  tie-dye-wallpaper \
  restart-animated-wallpaper-renderer \
  start-picom-effects \
  stop-animated-wallpaper \
  dual-monitor-wallpaper-sync \
  game-mode-guard \
  game-mode-fade \
  animated-wallpaper-picker \
  animated-wallpaper-speed \
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
chmod 0755 "$HOME_DIR/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper"

cp -a "$ROOT/runtime/picom-v13" "$HOME_DIR/.local/bin/picom"
chmod 0755 "$HOME_DIR/.local/bin/picom"

rsync -a "$ROOT/runtime/xfdesktop-transparent/" "$HOME_DIR/.local/opt/xfdesktop-transparent/"
find "$HOME_DIR/.local/opt/xfdesktop-transparent/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true

install_text "$ROOT/config/picom/picom.conf" "$HOME_DIR/.config/picom/picom.conf"
install_text "$ROOT/config/game-mode-guard/patterns" "$HOME_DIR/.config/game-mode-guard/patterns"

for desktop in "$ROOT"/autostart/*.desktop; do
  install_text "$desktop" "$HOME_DIR/.config/autostart/$(basename "$desktop")"
done

for service in "$ROOT"/systemd/user/*.service; do
  install_text "$service" "$HOME_DIR/.config/systemd/user/$(basename "$service")"
done

systemctl --user daemon-reload || true

echo "Installed xfcePlasma files for $USER_NAME."
echo "Recommended next steps:"
echo "  systemctl --user enable --now game-mode-guard.service"
echo "  systemctl --user restart tie-dye-wallpaper-mvp.service"
echo "  ~/.local/bin/start-animated-wallpaper-with-xfdesktop-icons"
