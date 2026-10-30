#!/usr/bin/env bash
# disk-maintenance.sh が「空き率が目標を下回ったときだけ ladder を回し、古いキャッシュだけ消す」ことを固定する
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
releases="$HOME/.codex/packages/standalone/releases"
codex_workspaces="$HOME/Documents/Codex"
mkdir -p "$releases/old" "$releases/current" "$codex_workspaces/2000-01-01" "$codex_workspaces/2999-01-01"
ln -s releases/current "$HOME/.codex/packages/standalone/current"
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
export GHQ_CLEAN_TEST_LOG="$tmp/ghq-clean.log"
export GHQ_CLEAN_SCRIPT="$tmp/ghq-clean-stub"
cat >"$GHQ_CLEAN_SCRIPT" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHQ_CLEAN_TEST_LOG"
exit "${GHQ_CLEAN_TEST_STATUS:-0}"
EOF
chmod +x "$GHQ_CLEAN_SCRIPT"
export PATH="$tmp/bin:/usr/bin:/bin"

# 空き率が目標以上なら何も回収しない
out=$(TARGET_PCT=0 bash "$script")
grep -q '空き率が目標以上なので何もしない' <<<"$out" || fail "目標以上で ladder を止めていない"
[ -e "$HOME/.cache/npm/old.tgz" ] || fail "目標以上で古いファイルを削除した"
[ ! -e "$DISK_MAINT_TEST_ENV_LOG" ] || fail "目標以上で nix の世代削除が走った"
[ "$(cat "$GHQ_CLEAN_TEST_LOG")" = "--dry-run" ] || fail "clone inventory をdry-runで呼んでいない"

# 乾燥実行は 30 日を超えた日付 folder だけを提示し、current release を削除候補にしない
out=$(TARGET_PCT=0 bash "$script" --dry-run)
grep -Fq '[archive candidate: older than 30d]' <<<"$out" || fail "古い Codex workspace を提示しない"
grep -Fq "$codex_workspaces/2000-01-01" <<<"$out" || fail "古い Codex workspace の path を表示しない"
grep -Fq "$codex_workspaces/2999-01-01" <<<"$out" && fail "新しい Codex workspace を archive 候補にした"
[ -d "$codex_workspaces/2000-01-01" ] || fail "dry-run が Codex workspace を変更した"

# TARGET_PCT=100 は届かない目標なので全段を通る。最後に候補を出して非 0 で終わる
# dry-run は何も消さない
out=$(TARGET_PCT=100 bash "$script" --dry-run) && fail "目標未達で 0 終了した"
[ -e "$HOME/.cache/npm/old.tgz" ] || fail "dry-run が古いファイルを削除した"
grep -q "nix: 30d より古い generation" <<<"$out" || fail "世代削除の見出しが無い"
grep -q '\[dry-run\] nix-env --delete-generations 30d' <<<"$out" || fail "dry-run が世代削除を表示していない"
[ -d "$releases/current" ] || fail "current release が dry-run で維持されていない"
grep -Fq "[dry-run] rm -rf $releases/old" <<<"$out" || fail "古い Codex release を dry-run が提示しない"
grep -Fq "[dry-run] rm -rf $releases/current" <<<"$out" && fail "current Codex release が dry-run の削除候補になった"
[ ! -e "$DISK_MAINT_TEST_ENV_LOG" ] || fail "dry-run が nix-env を実行した"

# 実削除は 30 日より古いファイルだけ
TARGET_PCT=100 bash "$script" >"$tmp/run.log" && fail "目標未達で 0 終了した"
[ ! -e "$HOME/.cache/npm/old.tgz" ] || fail "古いキャッシュが残っている"
[ ! -e "$HOME/Library/Caches/pip/old.whl" ] || fail "古い pip キャッシュが残っている"
[ -e "$HOME/.cache/npm/fresh.tgz" ] || fail "新しいキャッシュが消えた"
[ ! -e "$releases/old" ] || fail "古い Codex release が消えていない"
[ -d "$releases/current" ] || fail "current Codex release が削除された"
[ "$(readlink "$HOME/.codex/packages/standalone/current")" = "releases/current" ] || fail "current symlink が変わった"
[ "$(grep -c 'delete-generations 30d -p' "$tmp/env.log")" -eq 2 ] ||
  fail "世代削除が .nix-profile と home-manager の 2 プロファイルで走っていない"
grep -q -- '-link$' "$tmp/env.log" && fail "世代リンク自体をプロファイルとして渡している"
grep -qx 'store gc' "$tmp/nix.log" || fail "nix store gc が実行されていない"
grep -qx 'store optimise' "$tmp/nix.log" || fail "nix store optimise が実行されていない"
grep -q -- '-> caches:' "$tmp/run.log" || fail "段ごとの回収量が出ていない"

# nix が無い環境では nix の段を飛ばす (PATH 依存で store を触らない)
rm -f "$tmp/env.log" "$tmp/nix.log"
out=$(PATH="/usr/bin:/bin" TARGET_PCT=100 bash "$script") && fail "目標未達で 0 終了した"
grep -q 'nix: ' <<<"$out" && fail "nix 不在時に nix の段を実行した"
[ ! -e "$tmp/env.log" ] || fail "nix 不在時に nix-env を呼んだ"

# --days は整数のみ
if bash "$script" --days abc >/dev/null 2>&1; then
  fail "--days abc が受理された"
fi

# --archive の dry-run は S3 に触れず、source を残す
out=$(TARGET_PCT=100 bash "$script" --dry-run --archive "$codex_workspaces/2000-01-01")
grep -Fq "[dry-run] $codex_workspaces/2000-01-01" <<<"$out" || fail "archive dry-run が候補を表示しない"
[ -d "$codex_workspaces/2000-01-01" ] || fail "archive dry-run が source を削除した"

awk '$0 != "--dry-run" { exit 1 }' "$GHQ_CLEAN_TEST_LOG" || fail "disk maintenance がclone inventoryにapplyを渡した"
out=$(GHQ_CLEAN_TEST_STATUS=1 TARGET_PCT=0 bash "$script" 2>&1)
grep -q 'ghq clone report failed' <<<"$out" || fail "clone report failure がmaintenanceを止めたことを報告しない"

echo "OK: disk-maintenance"
