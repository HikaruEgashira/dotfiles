#!/usr/bin/env bash
# disk-maintenance.sh が「古いキャッシュだけ消し、nix の世代削除と GC を分けて呼ぶ」ことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$root/scripts/disk-maintenance.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

export HOME="$tmp/home"
mkdir -p "$HOME/.cache/npm/pkg" "$HOME/Library/Caches/pip"
mkdir -p "$HOME/.local/state/nix/profiles"
: >"$HOME/nix-profile-target"
: >"$HOME/.local/state/nix/profiles/home-manager-1-link"
ln -s nix-profile-target "$HOME/.nix-profile"
ln -s home-manager-1-link "$HOME/.local/state/nix/profiles/home-manager"
: >"$HOME/.local/state/nix/profiles/home-manager-1-link"
touch -t 202001010000 "$HOME/.cache/npm/old.tgz" "$HOME/Library/Caches/pip/old.whl"
echo fresh >"$HOME/.cache/npm/fresh.tgz"

mkdir -p "$tmp/bin"
cat >"$tmp/bin/nix-env" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DISK_MAINT_TEST_ENV_LOG"
EOF
cat >"$tmp/bin/nix" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DISK_MAINT_TEST_NIX_LOG"
EOF
chmod +x "$tmp/bin/nix-env" "$tmp/bin/nix"
export DISK_MAINT_TEST_ENV_LOG="$tmp/env.log"
export DISK_MAINT_TEST_NIX_LOG="$tmp/nix.log"
export PATH="$tmp/bin:/usr/bin:/bin"

# dry-run は何も消さない
out=$(bash "$script" --dry-run)
[ -e "$HOME/.cache/npm/old.tgz" ] || fail "dry-run が古いファイルを削除した"
grep -q 'nix: generations older than 30d' <<<"$out" || fail "世代削除の見出しが無い"
grep -q 'freed=.*(dry-run)' <<<"$out" || fail "dry-run の集計行が無い"

# 実削除は 30 日より古いファイルだけ
bash "$script" >"$tmp/run.log"
[ ! -e "$HOME/.cache/npm/old.tgz" ] || fail "古いキャッシュが残っている"
[ ! -e "$HOME/Library/Caches/pip/old.whl" ] || fail "古い pip キャッシュが残っている"
[ -e "$HOME/.cache/npm/fresh.tgz" ] || fail "新しいキャッシュが消えた"
[ "$(grep -c 'delete-generations 30d -p' "$tmp/env.log")" -eq 2 ] ||
  fail "世代削除が .nix-profile と home-manager の 2 プロファイルで走っていない"
grep -q -- '-link$' "$tmp/env.log" && fail "世代リンク自体をプロファイルとして渡している"
grep -qx 'store gc' "$tmp/nix.log" || fail "nix store gc が実行されていない"
grep -qx 'store optimise' "$tmp/nix.log" || fail "nix store optimise が実行されていない"
grep -q 'freed=' "$tmp/run.log" || fail "集計行が無い"

# nix が無い環境では skip する (PATH 依存で store を触らない)
out=$(PATH="/usr/bin:/bin" bash "$script")
grep -q 'nix-env が PATH に無い' <<<"$out" || fail "nix-env 不在時に skip していない"

# --days は整数のみ
if bash "$script" --days abc >/dev/null 2>&1; then
  fail "--days abc が受理された"
fi

echo "OK: disk-maintenance"
