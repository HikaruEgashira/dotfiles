#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for sandbox in seatbelt ""; do
  status=0
  CODEX_SANDBOX="$sandbox" bash -c '
    source "$1"
    shift
    printf "%s\n" "$@"
    exit 42
  ' _ "$root/modules/settings/aws-sandbox-notice.sh" sts 'argument with spaces' >"$tmp/out" 2>"$tmp/err" || status=$?
  [ "$status" -eq 42 ]
  printf '%s\n' sts 'argument with spaces' >"$tmp/expected"
  cmp "$tmp/expected" "$tmp/out"
  if [ "$sandbox" = seatbelt ]; then
    grep -q 'SSO キャッシュ' "$tmp/err"
    [ "$(wc -l <"$tmp/err")" -eq 1 ]
  else
    [ ! -s "$tmp/err" ]
  fi
done
printf '%s\n' 'aws sandbox notice: passed'
