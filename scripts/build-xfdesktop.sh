#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGE_VERSION=4.18.1-1build3
source_dir=
download=false
prefix=${HOME:?HOME is required}/.local/opt/xfdesktop-transparent
output=$ROOT/build/xfdesktop-transparent

usage() {
  printf 'usage: %s (--source-dir DIR | --download) [--prefix DIR] [--output DIR]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      source_dir=$2
      shift
      ;;
    --download) download=true ;;
    --prefix)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      prefix=$2
      shift
      ;;
    --output)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      output=$2
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$download" = true ] && [ -n "$source_dir" ]; then
  printf 'choose either --source-dir or --download\n' >&2
  exit 2
fi
if [ "$download" = false ] && [ -z "$source_dir" ]; then
  usage >&2
  exit 2
fi
case "$prefix" in /*) ;; *) printf 'prefix must be absolute: %s\n' "$prefix" >&2; exit 2 ;; esac
case "$output" in /*) ;; *) printf 'output must be absolute: %s\n' "$output" >&2; exit 2 ;; esac

for command_name in autoreconf make patch pkg-config install mktemp tar; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'missing build dependency: %s\n' "$command_name" >&2
    exit 1
  }
done
if [ "$download" = true ]; then
  command -v apt-get >/dev/null 2>&1 || {
    printf 'missing download tool: apt-get\n' >&2
    exit 1
  }
fi

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

if [ "$download" = true ]; then
  (
    cd "$work_dir"
    apt-get source "xfdesktop4=$PACKAGE_VERSION"
  )
  source_dir=$work_dir/xfdesktop4-4.18.1
fi
[ -f "$source_dir/configure" ] || {
  printf 'expected configured Ubuntu xfdesktop source at %s\n' "$source_dir" >&2
  exit 1
}

mkdir -p "$work_dir/source"
tar -C "$source_dir" --exclude=.git --exclude='./Makefile' --exclude='./config.*' \
  --exclude='./libtool' --exclude='*/.deps' --exclude='*/.libs' \
  --exclude='*.o' --exclude='*.lo' --exclude='*.la' -cf - . |
  tar -C "$work_dir/source" -xf -

patch -d "$work_dir/source" -p1 --forward < "$ROOT/patches/xfdesktop-transparent.patch"
(
  cd "$work_dir/source"
  autoreconf --force --install
  ./configure --prefix="$prefix"
  make -j"${JOBS:-$(getconf _NPROCESSORS_ONLN)}"
  make check
  make DESTDIR="$work_dir/stage" install
)

staged_prefix=$work_dir/stage$prefix
[ -x "$staged_prefix/bin/xfdesktop" ] || {
  printf 'xfdesktop build completed without the expected binary\n' >&2
  exit 1
}
mkdir -p "$output"
cp -a "$staged_prefix/." "$output/"
printf 'Built patched xfdesktop %s at %s\n' "$PACKAGE_VERSION" "$output"
printf 'The binary embeds prefix %s; rebuild for a different user prefix.\n' "$prefix"
