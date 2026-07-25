#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOME_DIR=${HOME:?HOME is required}
USER_NAME=$(id -un)
USER_ID=$(id -u)

install_text() {
  src=$1
  dest=$2
  mkdir -p "$(dirname "$dest")"
  sed \
    -e "s#/home/freezer#$HOME_DIR#g" \
    -e "s#USER=freezer#USER=$USER_NAME#g" \
    -e "s#LOGNAME=freezer#LOGNAME=$USER_NAME#g" \
    -e "s#/run/user/1000#/run/user/$USER_ID#g" \
    "$src" > "$dest"
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
  "$HOME_DIR/.local/opt/xfdesktop-transparent" \
  "$HOME_DIR/.config/picom" \
  "$HOME_DIR/.config/game-mode-guard" \
  "$HOME_DIR/.config/autostart" \
  "$HOME_DIR/.config/systemd/user"

for script in \
  tie-dye-wallpaper \
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
