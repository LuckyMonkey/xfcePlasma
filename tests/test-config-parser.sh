#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HOME="$tmp/home"
mkdir -p "$HOME"

# shellcheck source=../lib/xfce-plasma-common.sh
. "$repo_root/lib/xfce-plasma-common.sh"

conf="$tmp/test.conf"
cat > "$conf" <<'CONF'
# comment
include_regex = SteamLaunch AppId=[0-9]+
enter_delay_seconds=2
literal = $(touch should-not-exist)
CONF

[ "$(xfce_plasma_config_get "$conf" include_regex)" = 'SteamLaunch AppId=[0-9]+' ]
[ "$(xfce_plasma_config_get "$conf" enter_delay_seconds)" = '2' ]
[ "$(xfce_plasma_config_get "$conf" literal)" = '$(touch should-not-exist)' ]
[ ! -e "$tmp/should-not-exist" ]
if xfce_plasma_config_get "$conf" missing >/dev/null 2>&1; then
  echo "missing key unexpectedly succeeded" >&2
  exit 1
fi

printf 'test-config-parser ok\n'
