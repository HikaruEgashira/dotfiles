#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "gh-extension-audit test failed at line %s (exit %s)\n" "$LINENO" "$?" >&2' ERR

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/gh_extensions.py"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gh-extension-audit.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

ext="$tmp/extensions"
clone="$tmp/ghq/gh-linked"
mkdir -p "$ext/gh-managed" "$clone" "$ext/gh-nobin" "$ext/gh-noexec" "$ext/notes"
printf '#!/bin/sh\n' >"$ext/gh-managed/gh-managed"
chmod +x "$ext/gh-managed/gh-managed"
printf '#!/bin/sh\n' >"$clone/gh-linked"
chmod +x "$clone/gh-linked"
ln -s "$clone" "$ext/gh-linked"
ln -s "$tmp/ghq/gh-gone" "$ext/gh-gone"
printf '#!/bin/sh\n' >"$ext/gh-noexec/gh-noexec"
printf 'x\n' >"$ext/gh-file"

if output=$(python3 -I "$checker" "$ext" 2>&1); then
  printf 'FAIL: broken extensions were accepted\n%s\n' "$output" >&2
  exit 1
fi
[[ $output == *"OK        gh-managed     managed"* ]]
[[ $output == *"OK        gh-linked      symlink -> $clone"* ]]
[[ $output == *"DANGLING  gh-gone        symlink 先が無い: $tmp/ghq/gh-gone"* ]]
[[ $output == *"BROKEN    gh-nobin       gh-nobin が無い"* ]]
[[ $output == *"BROKEN    gh-noexec      gh-noexec が実行可能でない"* ]]
[[ $output == *"BROKEN    gh-file        directory ではない"* ]]
[[ $output == *"SKIP      notes"* ]]
[[ $output == *"docs/operations.md §4.8"* ]]

rm -rf "$ext/gh-gone" "$ext/gh-nobin" "$ext/gh-noexec" "$ext/gh-file"
output=$(python3 -I "$checker" "$ext")
[[ $output == *"OK: 3 gh extensions resolve to an executable"* ]]

output=$(python3 -I "$checker" "$tmp/absent")
[[ $output == *"OK: gh extension directory is absent"* ]]

if python3 -I "$checker" >/dev/null 2>&1; then
  printf 'FAIL: missing directory argument was accepted\n' >&2
  exit 1
fi

printf '%s\n' 'ok: dangling symlinks and missing executables fail, healthy extensions pass'
