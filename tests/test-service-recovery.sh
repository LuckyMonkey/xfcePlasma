#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
common="$repo_root/lib/xfce-plasma-common.sh"
starter="$repo_root/bin/start-animated-wallpaper-with-xfdesktop-icons"
restarter="$repo_root/bin/restart-animated-wallpaper-renderer"
wallpaper="$repo_root/systemd/user/tie-dye-wallpaper-mvp.service"
desktop="$repo_root/systemd/user/xfdesktop-transparent.service"
guard="$repo_root/systemd/user/game-mode-guard.service"

require() {
  local pattern=$1 file=$2 message=$3
  if ! rg -q -- "$pattern" "$file"; then
    printf 'service recovery regression: %s\n' "$message" >&2
    exit 1
  fi
}

reject() {
  local pattern=$1 file=$2 message=$3
  if rg -q -- "$pattern" "$file"; then
    printf 'service recovery regression: %s\n' "$message" >&2
    exit 1
  fi
}

for unit in "$wallpaper" "$desktop" "$guard"; do
  require '^Restart=on-failure$' "$unit" "$(basename "$unit") lost crash recovery"
  require '^RestartSec=' "$unit" "$(basename "$unit") lost restart backoff"
  require '^StartLimitIntervalSec=' "$unit" "$(basename "$unit") lost restart rate limiting"
  require '^StartLimitBurst=' "$unit" "$(basename "$unit") lost restart burst limit"
done

require 'xfce_plasma_wait_unit_active' "$common" 'stack restart no longer checks unit activation'
require 'xfce_plasma_backend_visible' "$common" 'backend X11 visibility check disappeared'
require 'xfce_plasma_wait_background_visible' "$common" 'stack readiness no longer waits for a visible backend'
require 'xwininfo -id' "$common" 'viewable X11 window verification disappeared'
require 'Map State:' "$common" 'X11 map-state verification disappeared'
require 'kill -0' "$common" 'backend readiness no longer verifies renderer process liveness'
require 'active but no viewable backend window appeared' "$common" 'visible-backend failure lost useful diagnostics'
require 'Wallpaper service did not become active' "$common" 'wallpaper startup failure lost useful diagnostics'
require 'Desktop icon service did not become active' "$common" 'desktop startup failure lost useful diagnostics'

require 'wallpaper-stack\.log' "$starter" 'session starter no longer preserves startup diagnostics'
require 'tail -n 20' "$starter" 'session starter no longer surfaces useful failure context'
reject 'xfce_plasma_restart_desktop_stack.*\|\| true' "$starter" 'session starter silently masks desktop stack failure'

require 'tie-dye-wallpaper\.log' "$restarter" 'manual restart helper no longer preserves diagnostics'
require 'tail -n 20' "$restarter" 'manual restart helper no longer surfaces useful failure context'
reject 'xfce_plasma_restart_desktop_stack.*\|\| true' "$restarter" 'manual restart helper silently masks desktop stack failure'

printf 'test-service-recovery ok\n'
