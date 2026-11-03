#!/usr/bin/env bash
# artex の local.env parser が KEY=VALUE 行だけを受け付け、メタ文字入りの値を壊さず、不正行で fail することを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
loader="$root/modules/programs/artex/load-env.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/good.env" <<'ENV'
# comment
PLAIN=abc
AMP='postgres://u:p@/db?host=/x&sslmode=disable'
DQ="a b"
EQ=k=v
ENV
out=$(bash -c ". '$loader'; load_env_file '$tmp/good.env'; printf '%s|%s|%s|%s\n' \"\$PLAIN\" \"\$AMP\" \"\$DQ\" \"\$EQ\"")
[ "$out" = 'abc|postgres://u:p@/db?host=/x&sslmode=disable|a b|k=v' ] || {
  printf 'FAIL: unexpected values: %s\n' "$out" >&2
  exit 1
}

printf 'export X=1\n' >"$tmp/bad.env"
if bash -c ". '$loader'; load_env_file '$tmp/bad.env'" 2>"$tmp/err"; then
  printf 'FAIL: shell syntax line was accepted\n' >&2
  exit 1
fi
grep -q 'bad.env:1 is not KEY=VALUE' "$tmp/err"

printf 'ok: artex load-env accepts KEY=VALUE only\n'
