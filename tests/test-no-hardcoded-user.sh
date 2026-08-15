#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pattern_file=$(mktemp)
trap 'rm -f "$pattern_file"' EXIT

{
  printf '/home/%s\n' 'freezer'
  printf '/run/user/%s\n' '1000'
  printf 'USER=%s\n' 'freezer'
  printf 'LOGNAME=%s\n' 'freezer'
  printf 'DISPLAY=:%s[.]%s\n' '0' '0'
  printf '/home/%s/src\n' 'freezer'
} > "$pattern_file"

scan_paths=(
  "$repo_root/bin"
  "$repo_root/install.sh"
  "$repo_root/lib"
  "$repo_root/src"
  "$repo_root/tests"
)

if rg -n -f "$pattern_file" "${scan_paths[@]}"; then
  echo "hardcoded personal runtime value found in portable project code" >&2
  exit 1
fi

printf 'test-no-hardcoded-user ok\n'
