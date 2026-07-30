#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOME_DIR=${HOME:?HOME is required}
USER_NAME=$(id -un)
action=install
dry_run=false
no_enable=false
use_bundled_runtime=false

usage() {
  printf 'usage: %s [--user] [--check] [--dry-run] [--no-enable] [--use-bundled-runtime] [--uninstall]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user) ;;
    --check) action=check ;;
    --dry-run) dry_run=true ;;
    --no-enable) no_enable=true ;;
    --use-bundled-runtime) use_bundled_runtime=true ;;
    --uninstall) action=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

check_dependencies() {
  if [ "$use_bundled_runtime" = true ]; then
    make -s -C "$ROOT" check-runtime-deps
  else
    make -s -C "$ROOT" check-deps
  fi
}

if [ "$action" = check ]; then
  check_dependencies
  exit $?
fi

PREFIX=$HOME_DIR/.local
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME_DIR/.config}
DATA_HOME=${XDG_DATA_HOME:-$HOME_DIR/.local/share}
STATE_HOME=${XDG_STATE_HOME:-$HOME_DIR/.local/state}
BIN_DIR=$PREFIX/bin
RENDERER_DIR=$PREFIX/lib/tie-dye-wallpaper
PROJECT_LIB_DIR=$PREFIX/lib/xfce-plasma
XFDESKTOP_DIR=$PREFIX/opt/xfdesktop-transparent
APPLICATION_DIR=$DATA_HOME/applications
ASSET_DIR=$DATA_HOME/xfce-plasma/assets
ICON_DIR=$DATA_HOME/icons/hicolor/scalable/apps
AUTOSTART_DIR=$CONFIG_HOME/autostart
SYSTEMD_DIR=$CONFIG_HOME/systemd/user
STATE_DIR=$STATE_HOME/xfce-plasma
MANIFEST=$STATE_DIR/install-manifest
CURRENT_SHADER_STATE=$STATE_HOME/tie-dye-wallpaper/current-shader
USER_SHADER_DIR=$DATA_HOME/xfce-plasma/user-shaders
PICOM_CONFIG=$CONFIG_HOME/picom/picom.conf
GAME_PATTERNS=$CONFIG_HOME/game-mode-guard/patterns

BIN_SCRIPTS=(
  tie-dye-wallpaper
  restart-animated-wallpaper-renderer
  start-picom-effects
  stop-animated-wallpaper
  dual-monitor-wallpaper-sync
  game-mode-guard
  game-mode-raster-wallpaper
  game-mode-fade
  animated-wallpaper-picker
  animated-wallpaper-speed
  xfce-plasma-doctor
  xfce-plasma-settings
  xfce-plasma-background
  xfce-plasma-restack-icons
  start-animated-wallpaper-with-xfdesktop-icons
  start-transparent-xfdesktop-session
  run-custom-xfdesktop
  stop-custom-xfdesktop
  restore-packaged-xfdesktop
  raise-floating-whisker
)

home_real=$(realpath -m -- "$HOME_DIR")
case "$home_real" in /|"") printf 'Refusing unsafe HOME: %s\n' "$HOME_DIR" >&2; exit 1 ;; esac

validate_home_path() {
  local path=$1 parent_real
  [ -n "$path" ] || { printf 'Refusing empty path\n' >&2; return 1; }
  case "$path" in
    /*) ;;
    *) printf 'Refusing non-absolute path: %s\n' "$path" >&2; return 1 ;;
  esac
  case "$path/" in
    *'/../'*|*'/./'*|*'//'*) printf 'Refusing non-normal path: %s\n' "$path" >&2; return 1 ;;
  esac
  parent_real=$(realpath -m -- "$(dirname "$path")")
  case "$parent_real" in
    "$home_real"|"$home_real"/*) ;;
    *) printf 'Refusing path whose parent resolves outside HOME: %s\n' "$path" >&2; return 1 ;;
  esac
}

validate_owned_path() {
  local path=$1
  validate_home_path "$path"
  case "$path" in
    "$BIN_DIR"/*|"$RENDERER_DIR"/*|"$PROJECT_LIB_DIR"/*|"$XFDESKTOP_DIR"/*|"$APPLICATION_DIR"/*|"$ASSET_DIR"/*|"$ICON_DIR"/*|"$AUTOSTART_DIR"/*|"$SYSTEMD_DIR"/*) ;;
    *) printf 'Refusing manifest path outside approved install roots: %s\n' "$path" >&2; return 1 ;;
  esac
}

validate_manifest() {
  local manifest=$1 path
  [ -e "$manifest" ] || return 0
  while IFS= read -r path; do
    [ -n "$path" ] || { printf 'Refusing empty manifest path in %s\n' "$manifest" >&2; return 1; }
    validate_owned_path "$path"
  done < "$manifest"
}

case "$(realpath -m -- "$STATE_DIR")" in
  "$home_real"|"$home_real"/*) ;;
  *) printf 'Refusing state directory outside HOME: %s\n' "$STATE_DIR" >&2; exit 1 ;;
esac

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
desired_manifest=$work_dir/desired-manifest
old_manifest=$work_dir/old-manifest
obsolete_manifest=$work_dir/obsolete-manifest
: > "$desired_manifest"
: > "$old_manifest"
: > "$obsolete_manifest"

if [ -r "$MANIFEST" ]; then
  cp -f -- "$MANIFEST" "$old_manifest"
  validate_manifest "$old_manifest"
elif [ "$action" = uninstall ]; then
  printf 'No xfcePlasma install manifest found: %s\n' "$MANIFEST" >&2
  exit 1
fi

record_desired() {
  validate_owned_path "$1"
  printf '%s\n' "$1" >> "$desired_manifest"
}

build_desired_manifest() {
  local file script
  record_desired "$PROJECT_LIB_DIR/xfce-plasma-common.sh"
  record_desired "$PROJECT_LIB_DIR/xfce-plasma-sources.sh"
  record_desired "$PROJECT_LIB_DIR/xfce-plasma-performance.sh"
  record_desired "$PROJECT_LIB_DIR/xfce-plasma-settings-ui"
  record_desired "$PROJECT_LIB_DIR/VERSION"
  record_desired "$PROJECT_LIB_DIR/install-origin"
  for script in "${BIN_SCRIPTS[@]}"; do record_desired "$BIN_DIR/$script"; done
  record_desired "$RENDERER_DIR/tie-dye-wallpaper"
  record_desired "$RENDERER_DIR/shader.fs"
  while IFS= read -r file; do record_desired "$RENDERER_DIR/shaders/${file#"$ROOT/runtime/tie-dye-wallpaper/shaders/"}"; done < <(find "$ROOT/runtime/tie-dye-wallpaper/shaders" -type f -print | sort)
  record_desired "$BIN_DIR/picom"
  while IFS= read -r file; do record_desired "$ASSET_DIR/thumbnails/${file#"$ROOT/assets/thumbnails/"}"; done < <(find "$ROOT/assets/thumbnails" -type f -print | sort)
  record_desired "$ICON_DIR/xfce-plasma.svg"
  while IFS= read -r file; do record_desired "$XFDESKTOP_DIR/${file#"$ROOT/runtime/xfdesktop-transparent/"}"; done < <(find "$ROOT/runtime/xfdesktop-transparent" -type f -print | sort)
  for file in "$ROOT"/applications/*.desktop; do record_desired "$APPLICATION_DIR/$(basename "$file")"; done
  for file in "$ROOT"/autostart/*.desktop; do record_desired "$AUTOSTART_DIR/$(basename "$file")"; done
  for file in "$ROOT"/systemd/user/*.service; do record_desired "$SYSTEMD_DIR/$(basename "$file")"; done
  sort -u -o "$desired_manifest" "$desired_manifest"
  validate_manifest "$desired_manifest"
}

build_desired_manifest
if [ -s "$old_manifest" ]; then
  sort -u -o "$old_manifest" "$old_manifest"
  comm -23 "$old_manifest" "$desired_manifest" > "$obsolete_manifest"
fi

if [ "$dry_run" = true ]; then
  if [ "$action" = uninstall ]; then
    printf 'Would uninstall %s project-owned file(s) for %s.\n' "$(wc -l < "$old_manifest")" "$USER_NAME"
    sed 's/^/  remove: /' "$old_manifest"
  else
    if [ "$use_bundled_runtime" = true ]; then origin=bundled-runtime; else origin=fresh-build; fi
    printf 'Would install/upgrade xfcePlasma for %s\n' "$USER_NAME"
    printf '  origin: %s\n  project files: %s\n' "$origin" "$(wc -l < "$desired_manifest")"
    printf '  binaries: %s\n  runtime: %s\n  services: %s\n' "$BIN_DIR" "$RENDERER_DIR" "$SYSTEMD_DIR"
    if [ -s "$obsolete_manifest" ]; then
      printf '  obsolete project files to remove:\n'
      sed 's/^/    /' "$obsolete_manifest"
    else
      printf '  obsolete project files to remove: none\n'
    fi
    printf '  preserve: user configuration, state, and user shaders\n'
    if [ "$no_enable" = false ]; then
      printf '  startup: XFCE autostart owns renderer and desktop-icon startup\n'
    else
      printf '  service enablement will not be changed\n'
    fi
  fi
  exit 0
fi

if [ "$action" = uninstall ]; then
  systemctl --user disable --now game-mode-guard.service tie-dye-wallpaper-mvp.service xfdesktop-transparent.service >/dev/null 2>&1 || true
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    validate_owned_path "$path"
    if [ -e "$path" ] || [ -L "$path" ]; then rm -f -- "$path"; fi
  done < "$old_manifest"
  rm -f -- "$MANIFEST"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  printf 'Uninstalled project-owned xfcePlasma files; user configuration, state, and user shaders were preserved.\n'
  exit 0
fi

if [ "$use_bundled_runtime" = true ]; then
  renderer_source=$ROOT/runtime/tie-dye-wallpaper/tie-dye-wallpaper
  settings_ui_source=$ROOT/runtime/xfce-plasma-settings-ui
  install_origin=bundled-runtime
else
  make -C "$ROOT" all
  renderer_source=$ROOT/build/xfce-plasma-renderer
  settings_ui_source=$ROOT/build/xfce-plasma-settings-ui
  install_origin=built-from-source
fi
[ -x "$renderer_source" ] || { printf 'Renderer artifact is missing: %s\n' "$renderer_source" >&2; exit 1; }
[ -x "$settings_ui_source" ] || { printf 'Settings UI artifact is missing: %s\n' "$settings_ui_source" >&2; exit 1; }

install_file() {
  local source=$1 destination=$2 mode=${3:-} directory temporary
  validate_owned_path "$destination"
  directory=$(dirname "$destination")
  mkdir -p -- "$directory"
  temporary=$(mktemp "$directory/.${destination##*/}.install.XXXXXX")
  if ! cp -a -- "$source" "$temporary"; then rm -f -- "$temporary"; return 1; fi
  if [ -n "$mode" ]; then chmod "$mode" "$temporary"
  else chmod --reference="$source" "$temporary" 2>/dev/null || chmod 0644 "$temporary"; fi
  mv -f -- "$temporary" "$destination"
}

install_config_if_missing() {
  local source=$1 destination=$2 directory temporary
  validate_home_path "$destination"
  [ ! -e "$destination" ] || return 0
  directory=$(dirname "$destination")
  mkdir -p -- "$directory"
  temporary=$(mktemp "$directory/.${destination##*/}.install.XXXXXX")
  if ! cp -a -- "$source" "$temporary"; then rm -f -- "$temporary"; return 1; fi
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$destination"
}

install_file "$ROOT/lib/xfce-plasma-common.sh" "$PROJECT_LIB_DIR/xfce-plasma-common.sh" 0644
install_file "$ROOT/lib/xfce-plasma-sources.sh" "$PROJECT_LIB_DIR/xfce-plasma-sources.sh" 0644
install_file "$ROOT/lib/xfce-plasma-performance.sh" "$PROJECT_LIB_DIR/xfce-plasma-performance.sh" 0644
install_file "$settings_ui_source" "$PROJECT_LIB_DIR/xfce-plasma-settings-ui" 0755
install_file "$ROOT/VERSION" "$PROJECT_LIB_DIR/VERSION" 0644
printf '%s\n' "$install_origin" > "$work_dir/install-origin"
install_file "$work_dir/install-origin" "$PROJECT_LIB_DIR/install-origin" 0644

for script in "${BIN_SCRIPTS[@]}"; do install_file "$ROOT/bin/$script" "$BIN_DIR/$script" 0755; done
install_file "$renderer_source" "$RENDERER_DIR/tie-dye-wallpaper" 0755
while IFS= read -r source_file; do
  install_file "$source_file" "$RENDERER_DIR/shaders/${source_file#"$ROOT/runtime/tie-dye-wallpaper/shaders/"}" 0644
done < <(find "$ROOT/runtime/tie-dye-wallpaper/shaders" -type f -print | sort)

if [ ! -e "$RENDERER_DIR/shader.fs" ]; then
  install_file "$ROOT/runtime/tie-dye-wallpaper/shader.fs" "$RENDERER_DIR/shader.fs" 0644
elif [ -s "$CURRENT_SHADER_STATE" ]; then
  selected=$(sed -n '1p' "$CURRENT_SHADER_STATE")
  case "$selected" in */*|""|.|..) selected= ;; esac
  if [ -n "$selected" ] && [ -r "$RENDERER_DIR/shaders/$selected" ]; then
    install_file "$RENDERER_DIR/shaders/$selected" "$RENDERER_DIR/shader.fs" 0644
  elif [ -n "$selected" ] && [ -r "$USER_SHADER_DIR/$selected" ]; then
    install_file "$USER_SHADER_DIR/$selected" "$RENDERER_DIR/shader.fs" 0644
  fi
fi

install_file "$ROOT/runtime/picom-v13" "$BIN_DIR/picom" 0755
while IFS= read -r source_file; do
  install_file "$source_file" "$ASSET_DIR/thumbnails/${source_file#"$ROOT/assets/thumbnails/"}" 0644
done < <(find "$ROOT/assets/thumbnails" -type f -print | sort)
install_file "$ROOT/assets/icons/xfce-plasma.svg" "$ICON_DIR/xfce-plasma.svg" 0644
while IFS= read -r source_file; do
  install_file "$source_file" "$XFDESKTOP_DIR/${source_file#"$ROOT/runtime/xfdesktop-transparent/"}"
done < <(find "$ROOT/runtime/xfdesktop-transparent" -type f -print | sort)

install_config_if_missing "$ROOT/config/picom/picom.conf" "$PICOM_CONFIG"
install_config_if_missing "$ROOT/config/game-mode-guard/patterns" "$GAME_PATTERNS"
for source_file in "$ROOT"/applications/*.desktop; do install_file "$source_file" "$APPLICATION_DIR/$(basename "$source_file")" 0644; done
for source_file in "$ROOT"/autostart/*.desktop; do install_file "$source_file" "$AUTOSTART_DIR/$(basename "$source_file")" 0644; done
for source_file in "$ROOT"/systemd/user/*.service; do install_file "$source_file" "$SYSTEMD_DIR/$(basename "$source_file")" 0644; done

while IFS= read -r path; do
  [ -n "$path" ] || continue
  validate_owned_path "$path"
  if [ -e "$path" ] || [ -L "$path" ]; then rm -f -- "$path"; fi
done < "$obsolete_manifest"

mkdir -p -- "$STATE_DIR"
manifest_tmp=$(mktemp "$STATE_DIR/.install-manifest.XXXXXX")
cp -f -- "$desired_manifest" "$manifest_tmp"
chmod 0600 "$manifest_tmp"
mv -f -- "$manifest_tmp" "$MANIFEST"
systemctl --user daemon-reload >/dev/null 2>&1 || true
if [ "$no_enable" = false ]; then
  # XFCE autostart runs these after RandR monitor layout has settled. Enabling
  # them in default.target creates an early-start/late-restart race.
  systemctl --user disable tie-dye-wallpaper-mvp.service xfdesktop-transparent.service >/dev/null 2>&1 || true
  systemctl --user enable game-mode-guard.service >/dev/null 2>&1 || true
fi

printf 'Installed xfcePlasma %s for %s from %s.\n' "$(sed -n '1p' "$ROOT/VERSION")" "$USER_NAME" "$install_origin"
printf 'Recommended next steps:\n'
printf '  %s/start-animated-wallpaper-with-xfdesktop-icons\n' "$BIN_DIR"
