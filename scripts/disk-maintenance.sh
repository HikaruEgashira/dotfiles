#!/usr/bin/env bash
# disk-maintenance.sh — nix store とキャッシュの膨張を上限内に保つ
#
# nix: 一定期間より古い generation を捨てて未参照 path を回収し、hardlink で重複を畳む
# cache: 一定期間触られていないファイルだけ削除する (ホットなキャッシュは残す)
set -euo pipefail

AGE_DAYS=30
DRY_RUN=0

usage() {
  echo "usage: $(basename "$0") [-n|--dry-run] [--days N]"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=1 ;;
  --days)
    AGE_DAYS="$2"
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

case "$AGE_DAYS" in
'' | *[!0-9]*)
  echo "--days は正の整数: $AGE_DAYS" >&2
  exit 1
  ;;
esac

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

avail() { df -Pk "$HOME" | awk 'NR==2 {print $4}'; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

prune() { # dir
  local dir=$1 n
  [ -d "$dir" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    n=$(find "$dir" -type f -mtime "+$AGE_DAYS" 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] && echo "  [dry-run] $dir ($n files)"
    return 0
  fi
  n=$(find "$dir" -type f -mtime "+$AGE_DAYS" -print -delete 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || return 0
  find "$dir" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  echo "  prune $dir ($n files)"
}

before=$(avail)

# nix-collect-garbage は ~/Library 配下の FUSE マウントを読みに行き失敗するため、世代削除と GC を分ける
if nix_env=$(command -v nix-env); then
  echo "==> nix: generations older than ${AGE_DAYS}d"
  for profile in "$HOME/.nix-profile" "$HOME/.local/state/nix/profiles"/*; do
    [ -e "$profile" ] || continue
    case "$profile" in *-link) continue ;; esac
    run "$nix_env" --delete-generations "${AGE_DAYS}d" -p "$profile"
  done
else
  echo "==> nix: skip (nix-env が PATH に無い)"
fi

if nix_bin=$(command -v nix); then
  run "$nix_bin" store gc
  run "$nix_bin" store optimise
else
  echo "==> nix: skip (nix が PATH に無い)"
fi

echo "==> cache: files untouched for ${AGE_DAYS}d"
for dir in "${CACHES[@]}"; do
  prune "$dir"
done

after=$(avail)
echo "---"
echo "freed=$(((after - before) / 1024))MiB avail=$((after / 1024))MiB$([ "$DRY_RUN" -eq 1 ] && echo ' (dry-run)')"
