#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if output=$(make -s -C "$repo_root" check-build-deps CC=xfce-plasma-missing-compiler 2>&1); then
  printf 'missing compiler was accepted\n' >&2
  exit 1
fi
case "$output" in
  *'ERROR    build: missing C compiler (xfce-plasma-missing-compiler)'*) ;;
  *) printf 'missing compiler diagnostic was not concise or actionable\n%s\n' "$output" >&2; exit 1 ;;
esac
case "$output" in
  *'Package '*|*'compilation terminated'*|*'No such file or directory'*)
    printf 'raw toolchain splatter leaked from dependency check\n%s\n' "$output" >&2
    exit 1 ;;
  *) ;;
esac

printf 'test-dependencies ok\n'
