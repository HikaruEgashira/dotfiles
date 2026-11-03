#!/usr/bin/env bash
# substitutable-gate.sh が「will be built」のうち config glue だけを許し、source build と fixed-output fetch を列挙して落とすことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$root/scripts/substitutable-gate.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mkdir -p "$tmp/bin"
cat >"$tmp/bin/nix" <<'EOF'
#!/bin/sh
[ "$1" = "--store" ] || { echo "nix called without --store: $*" >&2; exit 99; }
case "$2" in local?root=*) ;; *) echo "store is not a chroot: $2" >&2; exit 99 ;; esac
shift 2
case "$1 $2" in
  "build --dry-run")
    printf '%s\n' "$*" >>"$GATE_TEST_LOG"
    [ -z "${GATE_TEST_EVAL_ERROR:-}" ] || { echo "error: attribute missing" >&2; exit 1; }
    cat "$GATE_TEST_DRY_RUN" >&2
    ;;
  "derivation show")
    printf '%s\n' "$*" >>"$GATE_TEST_LOG"
    cat "$GATE_TEST_DRV_JSON"
    ;;
  *) echo "unexpected nix $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$tmp/bin/nix"
jq=$(command -v jq || nix shell --inputs-from "$root" nixpkgs#jq --command sh -c 'command -v jq')
ln -s "$jq" "$tmp/bin/jq"
export PATH="$tmp/bin:/usr/bin:/bin"
export GATE_TEST_LOG="$tmp/nix.log"
export GATE_TEST_DRY_RUN="$tmp/dry-run.txt"
export GATE_TEST_DRV_JSON="$tmp/drv.json"

cat >"$GATE_TEST_DRY_RUN" <<'EOF'
warning: Git tree '/x' is dirty
these 4 derivations will be built:
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-darwin-system-26.11.drv
  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-home-manager-generation.drv
  /nix/store/cccccccccccccccccccccccccccccccc-duckdb-1.5.5.drv
  /nix/store/dddddddddddddddddddddddddddddddd-crate-zbus-5.19.0.tar.gz.drv
these 2 paths will be fetched (1.0 MiB download, 2.0 MiB unpacked):
  /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-bun-1.4.4
  /nix/store/ffffffffffffffffffffffffffffffff-docker-29.9.2
EOF
cat >"$GATE_TEST_DRV_JSON" <<'EOF'
{"derivations":{
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-darwin-system-26.11.drv":{"env":{"preferLocalBuild":"1"},"outputs":{"out":{"path":"/nix/store/x"}}},
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-home-manager-generation.drv":{"env":{},"outputs":{"out":{"path":"/nix/store/y"}}},
  "cccccccccccccccccccccccccccccccc-duckdb-1.5.5.drv":{"env":{"src":"/nix/store/s-duckdb.tar.gz"},"outputs":{"out":{"path":"/nix/store/z"}}},
  "dddddddddddddddddddddddddddddddd-crate-zbus-5.19.0.tar.gz.drv":{"env":{"outputHash":"sha256-abc"},"outputs":{"out":{"hash":"abc","hashAlgo":"sha256","path":"/nix/store/w"}}}
}}
EOF

export SUBSTITUTABLE_GATE_ALLOWLIST="$tmp/allow.txt"
: >"$SUBSTITUTABLE_GATE_ALLOWLIST"

# 引数無しは usage
bash "$script" >/dev/null 2>&1 && fail "引数無しで成功した"

# source build だけを列挙して非 0。fixed-output fetch と config glue は件数のみ
out=$(bash "$script" .#a .#b 2>&1) && fail "source build があるのに 0 終了した"
grep -q 'FAIL: 1 derivation(s) would be built from source' <<<"$out" || fail "違反件数を報告しない: $out"
grep -q 'cccccccccccccccccccccccccccccccc-duckdb-1.5.5.drv' <<<"$out" || fail "source build を列挙しない"
grep -q 'dddddddddddddddddddddddddddddddd-crate-zbus' <<<"$out" && fail "fixed-output fetch を違反に数えた"
grep -q 'darwin-system-26.11.drv\|home-manager-generation.drv' <<<"$out" && fail "config glue を違反に数えた"
grep -q 'glue=2 fetch=1 build=1' <<<"$out" || fail "分類の件数を報告しない: $out"
grep -q 'eeeeeeee\|ffffffff' <<<"$out" && fail "fetch される path を build 対象に数えた"
grep -q 'build --dry-run --option substituters https://cache.nixos.org .#a .#b' "$GATE_TEST_LOG" || fail "cache.nixos.org だけを substituter に指定していない"
grep -q 'derivation show /nix/store/aaaaaaaa.*/nix/store/dddddddd' "$GATE_TEST_LOG" || fail "will be built の全 drv を derivation show に渡していない"

# allowlist の regex に合う source build は理由つきで許可する
printf '# comment\n^duckdb-[0-9.]+\\.drv$   # known\n' >"$SUBSTITUTABLE_GATE_ALLOWLIST"
out=$(bash "$script" .#a 2>&1) || fail "allowlist 済みで非 0 終了した: $out"
grep -q "allowed by $SUBSTITUTABLE_GATE_ALLOWLIST" <<<"$out" || fail "allowlist 適用を報告しない"
grep -q 'cccccccccccccccccccccccccccccccc-duckdb-1.5.5.drv' <<<"$out" || fail "許可した drv を表示しない"
printf '^duckdb-9\\.drv$\n' >"$SUBSTITUTABLE_GATE_ALLOWLIST"
bash "$script" .#a >/dev/null 2>&1 && fail "合わない regex で許可した"
: >"$SUBSTITUTABLE_GATE_ALLOWLIST"

# glue だけなら成功
: >"$GATE_TEST_LOG"
sed -i.bak '/duckdb\|crate-zbus/d' "$GATE_TEST_DRY_RUN"
cat >"$GATE_TEST_DRV_JSON" <<'EOF'
{"derivations":{
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-darwin-system-26.11.drv":{"env":{"preferLocalBuild":"1"},"outputs":{"out":{"path":"/nix/store/x"}}},
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-home-manager-generation.drv":{"env":{},"outputs":{"out":{"path":"/nix/store/y"}}}
}}
EOF
out=$(bash "$script" .#a) || fail "glue だけで非 0 終了した: $out"
grep -q 'OK: substitutable-gate' <<<"$out" || fail "成功を報告しない"

# build 対象 0 件なら derivation show を呼ばない
: >"$GATE_TEST_LOG"
printf 'warning: nothing\n' >"$GATE_TEST_DRY_RUN"
out=$(bash "$script" .#a) || fail "build 対象 0 件で非 0 終了した"
grep -q 'nothing to build' <<<"$out" || fail "build 対象 0 件を報告しない"
grep -q 'derivation show' "$GATE_TEST_LOG" && fail "build 対象 0 件で derivation show を呼んだ"

# eval 失敗は gate 失敗
out=$(GATE_TEST_EVAL_ERROR=1 bash "$script" .#a 2>&1) && fail "eval 失敗で 0 終了した"
grep -q 'FAIL: nix build --dry-run' <<<"$out" || fail "eval 失敗を報告しない"

echo "OK: substitutable-gate"
