#!/usr/bin/env bash
# installable の閉包のうち cache.nixos.org から取れず、かつ config glue でもない derivation を列挙し、1 件でもあれば失敗する
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: substitutable-gate.sh INSTALLABLE..." >&2
  exit 2
fi

SUBSTITUTER="${SUBSTITUTABLE_GATE_SUBSTITUTER:-https://cache.nixos.org}"
# 本機の /nix/store に既にある path は dry-run に出ないので、空の chroot store で評価して CI と同じ判定にする
STORE_ROOT="${SUBSTITUTABLE_GATE_STORE:-${XDG_CACHE_HOME:-$HOME/.cache}/substitutable-gate/store}"
ALLOWLIST="${SUBSTITUTABLE_GATE_ALLOWLIST:-$(dirname -- "${BASH_SOURCE[0]}")/substitutable-gate-allow.txt}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nix() { command nix --store "local?root=$STORE_ROOT" "$@"; }

# 1 行 1 regex。`#` 以降は理由
: >"$tmp/allow.re"
[ ! -f "$ALLOWLIST" ] || sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$ALLOWLIST" >"$tmp/allow.re"

# dry-run の報告は stderr。eval 失敗はそのまま gate の失敗にする
if ! nix build --dry-run --option substituters "$SUBSTITUTER" "$@" >/dev/null 2>"$tmp/dry-run.log"; then
  cat "$tmp/dry-run.log" >&2
  echo "FAIL: nix build --dry-run" >&2
  exit 1
fi

awk '
  /will be built:$/ { collecting = 1; next }
  collecting && /^  \/nix\/store\/.*\.drv$/ { sub(/^ +/, ""); print; next }
  { collecting = 0 }
' "$tmp/dry-run.log" >"$tmp/to-build.txt"

if [ ! -s "$tmp/to-build.txt" ]; then
  echo "OK: substitutable-gate (nothing to build)"
  exit 0
fi

# fixed-output は hash 固定の download、src / srcs を持つものは build。どちらも無ければ config glue
# shellcheck disable=SC2046
nix derivation show $(cat "$tmp/to-build.txt") |
  jq -r '
    .derivations | to_entries[]
    | (if (.value.outputs | any(has("hash"))) or (.value.env | has("outputHash")) then "fetch"
       elif (.value.env | has("src") or has("srcs")) then "build"
       else "glue" end) as $kind
    | "\($kind)\t/nix/store/\(.key)"
  ' >"$tmp/classified.txt"

count() { grep -c "^$1	" "$tmp/classified.txt" || true; }
echo "substitutable-gate: glue=$(count glue) fetch=$(count fetch) build=$(count build)"

grep '^build	' "$tmp/classified.txt" | cut -f2 >"$tmp/build.txt" || true
: >"$tmp/violations.txt"
: >"$tmp/allowed.txt"
while IFS= read -r drv; do
  name=${drv#/nix/store/*-}
  if [ -s "$tmp/allow.re" ] && grep -qE -f "$tmp/allow.re" <<<"$name"; then
    echo "$drv" >>"$tmp/allowed.txt"
  else
    echo "$drv" >>"$tmp/violations.txt"
  fi
done <"$tmp/build.txt"

if [ -s "$tmp/allowed.txt" ]; then
  echo "allowed by $ALLOWLIST:"
  sed 's/^/  /' "$tmp/allowed.txt"
fi

if [ -s "$tmp/violations.txt" ]; then
  echo "FAIL: $(wc -l <"$tmp/violations.txt" | tr -d ' ') derivation(s) would be built from source (not in $SUBSTITUTER):" >&2
  sed 's/^/  /' "$tmp/violations.txt" >&2
  exit 1
fi

echo "OK: substitutable-gate"
