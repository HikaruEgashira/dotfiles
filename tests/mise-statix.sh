#!/usr/bin/env bash
# mise.nix が statix の empty pattern を踏まないことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
file="$root/modules/programs/mise.nix"

if grep -Fqx '{ ... }:' "$file"; then
  printf '%s\n' 'FAIL: mise.nix uses an empty function argument pattern' >&2
  exit 1
fi
grep -Fq 'config.home.homeDirectory' "$file"

printf '%s\n' 'ok: mise.nix keeps config and avoids the empty function argument pattern'
