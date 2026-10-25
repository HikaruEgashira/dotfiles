#!/usr/bin/env bash
# disk-maintenance.sh — 空き率が TARGET_PCT を下回ったときだけ、失うものの小さい順に回収する
#
# 週次・年齢ベースの掃除は増加に追従しない (週 5GB 増えて 3GB しか消えない)。トリガを
# 空き率に置き、回収できる段を順に試して目標に届いた時点で止める。
# 各段の「失うもの」:
#   1-3 nix    : 未参照 path と古い generation。再ビルドで戻る
#   4-5 cache  : 再取得できるキャッシュ
#   6   trash  : 7 日以上放置されたゴミ箱
#   7   podman : --podman-machine で明示指定した停止済み VM のみ (image は再 pull できる)
set -euo pipefail

TARGET_PCT=${TARGET_PCT:-10}
CACHE_AGE_DAYS=30
TRASH_AGE_DAYS=7
PODMAN_MACHINE=
DRY_RUN=0

usage() {
  cat >&2 <<'EOF'
usage: disk-maintenance.sh [-n|--dry-run] [--days N] [--target PCT] [--podman-machine NAME]
  --days N             キャッシュと nix generation の保持日数 (既定 30)
  --target PCT         目標空き率 % (既定 10、環境変数 TARGET_PCT)
  --podman-machine N   指定した停止済み podman VM を削除して回収する
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=1 ;;
  --days)
    CACHE_AGE_DAYS="$2"
    shift
    ;;
  --target)
    TARGET_PCT="$2"
    shift
    ;;
  --podman-machine)
    PODMAN_MACHINE="$2"
    shift
    ;;
  -h | --help) usage ;;
  *)
    echo "unknown option: $1" >&2
    usage 1
    ;;
  esac
  shift
done

for n in "$CACHE_AGE_DAYS" "$TARGET_PCT"; do
  case "$n" in
  '' | *[!0-9]*)
    echo "正の整数を期待: $n" >&2
    exit 1
    ;;
  esac
done

CACHES=(
  "$HOME/.cache/npm"
  "$HOME/.cache/pnpm"
  "$HOME/.cache/node"
  "$HOME/.cache/uv"
  "$HOME/.cache/puppeteer"
  "$HOME/.cache/codex-runtimes"
  "$HOME/Library/Caches/pip"
  "$HOME/Library/Caches/pnpm"
  "$HOME/Library/Caches/bun"
  "$HOME/Library/Caches/node-gyp"
)

avail_mib() { df -Pk "$HOME" | awk 'NR==2 {print int($4 / 1024)}'; }
used_pct() { df -Pk "$HOME" | awk 'NR==2 {print int($3 * 100 / ($3 + $4))}'; }
free_pct() { echo $((100 - $(used_pct))); }
below_target() { [ "$(free_pct)" -lt "$TARGET_PCT" ]; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
    return 0
  fi
  "$@"
}

pace() { # label
  local after delta
  after=$(avail_mib)
  delta=$((after - BEFORE))
  echo "  -> $1: ${delta}MiB 増 (空き ${after}MiB)"
  BEFORE=$after
}

step_nix_generations() {
  command -v nix-env >/dev/null || return 0
  echo "==> nix: ${CACHE_AGE_DAYS}d より古い generation"
  local profile
  for profile in "$HOME/.nix-profile" "$HOME/.local/state/nix/profiles"/*; do
    [ -e "$profile" ] || continue
    case "$profile" in *-link) continue ;; esac
    run nix-env --delete-generations "${CACHE_AGE_DAYS}d" -p "$profile"
  done
}

step_nix_gc() {
  command -v nix >/dev/null || return 0
  echo "==> nix: 未参照 path の回収"
  # nix-collect-garbage は ~/Library 配下の FUSE マウントを読みに行き失敗するため nix store gc を使う
  run nix store gc
}

step_nix_optimise() {
  command -v nix >/dev/null || return 0
  echo "==> nix: 同一内容の hardlink 化"
  run nix store optimise
}

prune() { # dir age_days
  local dir=$1 n
  [ -d "$dir" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    n=$(find "$dir" -type f -mtime "+$CACHE_AGE_DAYS" 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] && echo "  [dry-run] $dir ($n files)"
    return 0
  fi
  n=$(find "$dir" -type f -mtime "+$CACHE_AGE_DAYS" -print -delete 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || return 0
  find "$dir" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  echo "  prune $dir ($n files)"
}

step_caches() {
  echo "==> cache: ${CACHE_AGE_DAYS}d 触られていないファイル"
  local dir
  for dir in "${CACHES[@]}"; do prune "$dir"; done
}

step_trash() {
  echo "==> trash: ${TRASH_AGE_DAYS}d 以上前の項目"
  [ -d "$HOME/.Trash" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    find "$HOME/.Trash" -mindepth 1 -maxdepth 1 -mtime "+$TRASH_AGE_DAYS" 2>/dev/null | wc -l |
      xargs -I {} echo "  [dry-run] ~/.Trash ({} items)"
    return 0
  fi
  find "$HOME/.Trash" -mindepth 1 -maxdepth 1 -mtime "+$TRASH_AGE_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

step_podman_machine() {
  [ -n "$PODMAN_MACHINE" ] || return 0
  command -v podman >/dev/null || return 0
  echo "==> podman: machine $PODMAN_MACHINE を削除 (image は再 pull)"
  run podman machine rm --force "$PODMAN_MACHINE"
}

report_candidates() {
  echo "!! 目標空き率 ${TARGET_PCT}% に届いていない。判断が要る候補:" >&2
  if command -v podman >/dev/null; then
    while IFS='|' read -r name last disk; do
      [ -n "$name" ] || continue
      echo "  podman machine $name (${disk}, 最終起動 ${last}) — 停止して削除すると回収" >&2
    done < <(podman machine list --format '{{.Name}}|{{.LastUp}}|{{.DiskSize}}' 2>/dev/null)
  fi
  local odd
  for odd in "$HOME/.local/share/artex/import" "$HOME/.local/share/containers/podman/machine"; do
    [ -e "$odd" ] && echo "  $(du -sh "$odd" 2>/dev/null | cut -f1) $odd" >&2
  done
  echo "  20G 前後は APFS の OS 側 (Preboot / ステージ済み更新)。sudo が要るので手で: docs/operations.md「容量」" >&2
}

BEFORE=$(avail_mib)
echo "start: 空き $(free_pct)% (${BEFORE}MiB)"

if ! below_target; then
  echo "空き率が目標以上なので何もしない"
  exit 0
fi

for step in nix_generations nix_gc nix_optimise caches trash podman_machine; do
  below_target || break
  "step_$step"
  pace "$step"
done

echo "---"
if below_target; then
  report_candidates
  exit 1
fi
echo "空き $(free_pct)% ($(avail_mib)MiB)${DRY_RUN:+ (dry-run)}"
