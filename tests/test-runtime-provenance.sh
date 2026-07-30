#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

sha256sum --check runtime/SHA256SUMS
grep -q 'TRANSPARENT_BACKGROUND' patches/xfdesktop-transparent.patch
grep -q 'd87a5ba3af7a9ee3c4e040ee29b2dea7e9e46317' scripts/build-picom.sh
grep -q 'wrap_mode=nodownload' scripts/build-picom.sh
grep -q '4.18.1-1build3' scripts/build-xfdesktop.sh

printf 'runtime provenance tests passed\n'
