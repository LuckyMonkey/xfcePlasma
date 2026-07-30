#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PICOM_COMMIT=d87a5ba3af7a9ee3c4e040ee29b2dea7e9e46317
source_dir=
download=false
output=$ROOT/build/picom-v13-from-source

usage() {
  printf 'usage: %s (--source-dir DIR | --download) [--output FILE]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      source_dir=$2
      shift
      ;;
    --download) download=true ;;
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

for command_name in cmake git meson ninja pkg-config install mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'missing build dependency: %s\n' "$command_name" >&2
    exit 1
  }
done

work_dir=$(mktemp -d)
wrap_mode=nodownload
trap 'rm -rf -- "$work_dir"' EXIT

if [ "$download" = true ]; then
  source_dir=$work_dir/picom
  git clone --filter=blob:none https://github.com/yshui/picom.git "$source_dir"
  git -C "$source_dir" checkout --detach "$PICOM_COMMIT"
  git -C "$source_dir" submodule update --init --recursive
  wrap_mode=default
fi

[ -d "$source_dir/.git" ] || {
  printf 'Picom source must be a Git checkout: %s\n' "$source_dir" >&2
  exit 1
}
actual_commit=$(git -C "$source_dir" rev-parse HEAD)
[ "$actual_commit" = "$PICOM_COMMIT" ] || {
  printf 'wrong Picom revision: expected %s, got %s\n' "$PICOM_COMMIT" "$actual_commit" >&2
  exit 1
}

meson setup "$work_dir/build" "$source_dir" --buildtype=release --wrap-mode="$wrap_mode"
ninja -C "$work_dir/build"
[ -x "$work_dir/build/src/picom" ] || {
  printf 'Picom build completed without the expected src/picom binary\n' >&2
  exit 1
}
mkdir -p -- "$(dirname "$output")"
install -m 0755 "$work_dir/build/src/picom" "$output"
printf 'Built Picom %s at %s\n' "$PICOM_COMMIT" "$output"
printf 'Compare it deliberately; compiler and dependency versions can change the checksum.\n'
