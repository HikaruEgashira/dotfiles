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
touch -t 202001010000 "$HOME/.cache/npm/old.tgz" "$HOME/Library/Caches/pip/old.whl"
echo fresh >"$HOME/.cache/npm/fresh.tgz"
artex="$HOME/.local/share/artex"
mkdir -p "$artex/import" "$artex/pg" "$HOME/.local/share/containers"
echo old >"$artex/import/old.tar.zst"
touch -t 202001010000 "$artex/import/old.tar.zst"
echo fresh >"$artex/import/fresh.tar.zst"
echo data >"$artex/pg/base"
touch -t 202001010000 "$artex/pg/base"
mkdir -p "$artex/backups/deploy-a" "$artex/backups/deploy-b" "$artex/backups/deploy-c" "$artex/deploy-staging/c1"
touch -t 202001010000 "$artex/backups/deploy-a"
touch -t 202101010000 "$artex/backups/deploy-b"
touch -t 202201010000 "$artex/backups/deploy-c"
repo="$HOME/ghq/github.com/owner/repo"
mkdir -p "$repo/.pnpm-store/v3" "$repo/packages/web/.local/share" "$HOME/ghq/.pnpm-store"
sizes="$HOME/.local/state/disk-maintenance/sizes.tsv"

mkdir -p "$tmp/bin"
cat >"$tmp/bin/nix-collect-garbage" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DISK_MAINT_TEST_GC_LOG"
EOF
cat >"$tmp/bin/nix" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DISK_MAINT_TEST_NIX_LOG"
EOF
cat >"$tmp/bin/podman" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DISK_MAINT_TEST_PODMAN_LOG"
EOF
chmod +x "$tmp/bin/nix-collect-garbage" "$tmp/bin/nix" "$tmp/bin/podman"
export DISK_MAINT_TEST_PODMAN_LOG="$tmp/podman.log"
export DISK_MAINT_TEST_GC_LOG="$tmp/gc.log"
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

# 空き率が目標以上でも tombstone と size 記録は毎回。ladder は回さない
out=$(TARGET_PCT=0 bash "$script" --dry-run)
grep -Fq "tombstone: $repo/.pnpm-store" <<<"$out" || fail "repo 直下の .pnpm-store を tombstone にしない"
grep -Fq "tombstone: $HOME/ghq/.pnpm-store" <<<"$out" || fail "ghq 直下の .pnpm-store を tombstone にしない"
[ -d "$repo/.pnpm-store" ] || fail "dry-run が .pnpm-store を消した"
[ ! -e "$sizes" ] || fail "dry-run が sizes.tsv に書いた"
grep -q '^==> sizes: ' <<<"$out" || fail "size 記録を表示しない"
out=$(TARGET_PCT=0 bash "$script")
grep -q '空き率が目標以上なので何もしない' <<<"$out" || fail "目標以上で ladder を止めていない"
[ -e "$HOME/.cache/npm/old.tgz" ] || fail "目標以上で古いファイルを削除した"
[ -e "$artex/import/old.tar.zst" ] || fail "目標以上で artex import を削除した"
[ ! -e "$DISK_MAINT_TEST_GC_LOG" ] || fail "目標以上で nix GC が走った"
[ ! -e "$DISK_MAINT_TEST_PODMAN_LOG" ] || fail "目標以上で podman を触った"
[ "$(tail -n 1 "$GHQ_CLEAN_TEST_LOG")" = "--dry-run" ] || fail "clone inventory をdry-runで呼んでいない"
[ ! -e "$repo/.pnpm-store" ] || fail "repo 直下の .pnpm-store が残っている"
[ ! -e "$HOME/ghq/.pnpm-store" ] || fail "ghq 直下の .pnpm-store が残っている"
[ -d "$repo/packages/web/.local" ] || fail "packages/*/.local を削除した (repo 側の責務)"
[ "$(wc -l <"$sizes" | tr -d ' ')" -eq 1 ] || fail "sizes.tsv に 1 行記録されていない"
awk -F'\t' -v d="$(date +%F)" 'NF != 4 || $1 != d { exit 1 }' "$sizes" || fail "sizes.tsv の列が 日付 + 3 者 でない"
# 同じ週に再実行しても追記しない。前回記録から増えていれば差分を出す
awk -F'\t' -v OFS='\t' '{ $2 = 0; print }' "$sizes" >"$sizes.new" && mv "$sizes.new" "$sizes"
out=$(TARGET_PCT=0 bash "$script")
[ "$(wc -l <"$sizes" | tr -d ' ')" -eq 1 ] || fail "7 日以内の再実行で sizes.tsv に追記した"
grep -q "増加: $artex" <<<"$out" || fail "前回比の増加を表示しない"
grep -q "増加: $HOME/.local/share/containers" <<<"$out" && fail "増えていない項目を増加と表示した"
# 前回記録が 7 日より古ければ追記する
awk -F'\t' -v OFS='\t' '{ $1 = "2000-01-01"; print }' "$sizes" >"$sizes.new" && mv "$sizes.new" "$sizes"
TARGET_PCT=0 bash "$script" >/dev/null
[ "$(wc -l <"$sizes" | tr -d ' ')" -eq 2 ] || fail "7 日より古い記録の後に追記していない"

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
grep -q "nix: 30d より古い generation と未参照 path の回収" <<<"$out" || fail "nix GC の見出しが無い"
grep -q '\[dry-run\] nix-collect-garbage --delete-older-than 30d' <<<"$out" || fail "dry-run が nix GC を表示していない"
[ -d "$releases/current" ] || fail "current release が dry-run で維持されていない"
grep -Fq "[dry-run] rm -rf $releases/old" <<<"$out" || fail "古い Codex release を dry-run が提示しない"
grep -Fq "[dry-run] rm -rf $releases/current" <<<"$out" && fail "current Codex release が dry-run の削除候補になった"
[ ! -e "$DISK_MAINT_TEST_GC_LOG" ] || fail "dry-run が nix-collect-garbage を実行した"
grep -Fq "[dry-run] $artex/import (1 files)" <<<"$out" || fail "古い artex import を dry-run が提示しない"
grep -Fq "[dry-run] rm -rf $artex/backups/deploy-a" <<<"$out" || fail "古い artex 世代を dry-run が提示しない"
grep -Fq "[dry-run] rm -rf $artex/backups/deploy-c" <<<"$out" && fail "新しい artex 世代が削除候補になった"
grep -Fq '[dry-run] podman system prune -f' <<<"$out" || fail "dry-run が podman system prune を提示しない"
grep -Eq '^(system prune|machine rm)' "$DISK_MAINT_TEST_PODMAN_LOG" && fail "dry-run が podman の削除を実行した"
grep -Fq "$repo/packages/web/.local" <<<"$(TARGET_PCT=100 bash "$script" --dry-run 2>&1 >/dev/null)" || fail "packages/*/.local を候補として報告しない"

# 実削除は 30 日より古いファイルだけ
TARGET_PCT=100 bash "$script" >"$tmp/run.log" && fail "目標未達で 0 終了した"
[ ! -e "$HOME/.cache/npm/old.tgz" ] || fail "古いキャッシュが残っている"
[ ! -e "$artex/import/old.tar.zst" ] || fail "古い artex import が残っている"
[ -e "$artex/import/fresh.tar.zst" ] || fail "新しい artex import が消えた"
[ -e "$artex/pg/base" ] || fail "artex pg を削除した"
[ ! -e "$artex/backups/deploy-a" ] || fail "古い artex 世代が残っている"
[ -d "$artex/backups/deploy-b" ] && [ -d "$artex/backups/deploy-c" ] || fail "新しい artex 世代を消した"
[ -d "$artex/deploy-staging/c1" ] || fail "KEEP 以内の deploy-staging を消した"
grep -qx 'system prune -f' "$DISK_MAINT_TEST_PODMAN_LOG" || fail "podman system prune が実行されていない"
grep -q 'machine rm' "$DISK_MAINT_TEST_PODMAN_LOG" && fail "--podman-machine 無しで machine を削除した"
[ ! -e "$HOME/Library/Caches/pip/old.whl" ] || fail "古い pip キャッシュが残っている"
[ -e "$HOME/.cache/npm/fresh.tgz" ] || fail "新しいキャッシュが消えた"
[ ! -e "$releases/old" ] || fail "古い Codex release が消えていない"
[ -d "$releases/current" ] || fail "current Codex release が削除された"
[ "$(readlink "$HOME/.codex/packages/standalone/current")" = "releases/current" ] || fail "current symlink が変わった"
[ "$(cat "$tmp/gc.log")" = "--delete-older-than 30d" ] || fail "nix-collect-garbage が保持日数つきで 1 回だけ走っていない"
grep -qx 'store optimise' "$tmp/nix.log" || fail "nix store optimise が実行されていない"
grep -q -- '-> caches:' "$tmp/run.log" || fail "段ごとの回収量が出ていない"

# nix が無い環境では nix の段を飛ばす (PATH 依存で store を触らない)
rm -f "$tmp/gc.log" "$tmp/nix.log"
out=$(PATH="/usr/bin:/bin" TARGET_PCT=100 bash "$script") && fail "目標未達で 0 終了した"
grep -q 'nix: ' <<<"$out" && fail "nix 不在時に nix の段を実行した"
[ ! -e "$tmp/gc.log" ] || fail "nix 不在時に nix-collect-garbage を呼んだ"

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
