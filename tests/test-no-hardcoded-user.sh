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

if rg -n -f "$pattern_file" "$repo_root/lib" "$repo_root/tests"; then
  echo "hardcoded personal runtime value found in new portable foundation" >&2
  exit 1
fi

printf 'test-no-hardcoded-user ok\n'
