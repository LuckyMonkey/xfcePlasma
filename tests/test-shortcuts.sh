#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/bin" "$tmp/prefix/bin"
XFCONF_DB=$tmp/xfconf.tsv
: > "$XFCONF_DB"

cat > "$tmp/bin/xfconf-query" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
db=$XFCONF_DB
if [ "${3:-}" = -lv ]; then
    awk -F '\t' '{printf "%s   %s\n", $1, $2}' "$db"
    exit 0
fi
property=${4:-}
if printf '%s\n' "$@" | grep -qx -- -r; then
    awk -F '\t' -v property="$property" '$1 != property' "$db" > "$db.new"
    mv "$db.new" "$db"
    exit 0
fi
value=
previous=
for argument in "$@"; do
    if [ "$previous" = -s ]; then value=$argument; fi
    previous=$argument
done
if [ -n "$value" ]; then
    awk -F '\t' -v property="$property" '$1 != property' "$db" > "$db.new"
    printf '%s\t%s\n' "$property" "$value" >> "$db.new"
    mv "$db.new" "$db"
    exit 0
fi
awk -F '\t' -v property="$property" '$1 == property {print $2; found=1} END {if (!found) exit 1}' "$db"
MOCK
chmod +x "$tmp/bin/xfconf-query"

export HOME="$tmp/home" PATH="$tmp/bin:$PATH" XFCONF_DB XFCE_PLASMA_PREFIX="$tmp/prefix"
settings=$repo_root/bin/xfce-plasma-settings

[ "$($settings shortcuts get wallpaper-prev)" = "" ]
$settings shortcuts set wallpaper-prev '<Super>bracketleft' >/dev/null
[ "$($settings shortcuts get wallpaper-prev)" = '<Super>bracketleft' ]
$settings shortcuts reset wallpaper-prev >/dev/null
[ "$($settings shortcuts get wallpaper-prev)" = '<Primary><Alt><Shift>Left' ]
printf '/commands/custom/<Super>x\t/usr/bin/unrelated\n' >> "$XFCONF_DB"
if $settings shortcuts set wallpaper-next '<Super>x' >/dev/null 2>&1; then
    echo 'conflicting shortcut unexpectedly overwritten' >&2
    exit 1
fi
$settings shortcuts clear wallpaper-prev
[ "$($settings shortcuts get wallpaper-prev)" = "" ]
$settings shortcuts list | grep -q '^open-settings[[:space:]]*unassigned$'

printf 'test-shortcuts ok\n'
