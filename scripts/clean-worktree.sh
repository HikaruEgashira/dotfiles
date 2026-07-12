#!/usr/bin/env bash
# clean-worktree.sh — merged / stale (default 7d) な git worktree を一括削除する
#
# 対象: ~/ghq/github.com/*/* の全 main repo に登録された linked worktree
#       (herdr / gh-wt / claude agent worktree / 手動作成を問わない)
#
# 削除条件 (いずれか):
#   merged - branch の PR が merged (gh)、または default branch に取り込み済み
#   stale  - 最終 git 操作から DAYS 日以上経過し、かつ working tree が clean
# dirty な worktree は --force なしでは削除しない。
# merged で削除した場合のみ local branch も削除する (stale は branch を残す)。
set -euo pipefail

GHQ_ROOT="${GHQ_ROOT:-$HOME/ghq/github.com}"
DAYS=7
DRY_RUN=0
FORCE=0

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  echo "usage: $(basename "$0") [-n|--dry-run] [--days N] [--force]"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    --days) DAYS="$2"; shift ;;
    --force) FORCE=1 ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
  shift
done

NOW=$(date +%s)
THRESHOLD=$((NOW - DAYS * 86400))
HAVE_GH=0
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && HAVE_GH=1

removed=0 skipped=0

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# PR が merged か (gh が使えて remote がある場合のみ判定可)
pr_merged() { # repo branch
  [ "$HAVE_GH" -eq 1 ] || return 1
  git -C "$1" remote get-url origin >/dev/null 2>&1 || return 1
  local state
  state=$(gh pr list --repo "$(git -C "$1" remote get-url origin)" \
    --head "$2" --state merged --json number --jq 'length' 2>/dev/null) || return 1
  [ "${state:-0}" -gt 0 ]
}

# default branch に取り込み済みか (squash merge は検出不可 → pr_merged が補完)
locally_merged() { # repo sha
  local def
  def=$(git -C "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) \
    || def=$(git -C "$1" symbolic-ref -q --short HEAD 2>/dev/null) || return 1
  git -C "$1" merge-base --is-ancestor "$2" "$def" 2>/dev/null
}

# worktree の最終アクティビティ (git 操作で更新される index/HEAD の mtime と commit 時刻の新しい方)
last_activity() { # worktree_path gitdir
  local commit_ts=0 fs_ts=0 f
  commit_ts=$(git -C "$1" log -1 --format=%ct 2>/dev/null) || commit_ts=0
  case "$commit_ts" in '' | *[!0-9]*) commit_ts=0 ;; esac
  for f in "$2/index" "$2/HEAD"; do
    if [ -e "$f" ]; then
      local m; m=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null) || continue
      case "$m" in '' | *[!0-9]*) continue ;; esac
      [ "$m" -gt "$fs_ts" ] && fs_ts=$m
    fi
  done
  [ "$commit_ts" -gt "$fs_ts" ] && echo "$commit_ts" || echo "$fs_ts"
}

for repo in "$GHQ_ROOT"/*/*/; do
  repo=${repo%/}
  [ -d "$repo/.git" ] || continue
  git -C "$repo" worktree list --porcelain 2>/dev/null | grep -q '^worktree .*' || continue

  # 実体が消えた登録を先に掃除
  run git -C "$repo" worktree prune

  main_path=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname)

  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt=${line#worktree } ; branch="" sha="" locked=0 ;;
      HEAD\ *) sha=${line#HEAD } ;;
      branch\ *) branch=${line#branch refs/heads/} ;;
      locked*) locked=1 ;;
      "")
        [ -n "${wt:-}" ] || continue
        [ "$wt" = "$main_path" ] && { wt=""; continue; }
        [ -d "$wt" ] || { wt=""; continue; }

        reason=""
        if [ -n "$branch" ] && { pr_merged "$repo" "$branch" || locally_merged "$repo" "$sha"; }; then
          reason="merged"
        else
          gitdir=$(git -C "$wt" rev-parse --git-dir 2>/dev/null) || gitdir=""
          activity=$(last_activity "$wt" "$gitdir")
          [ "$activity" -lt "$THRESHOLD" ] && reason="stale(${DAYS}d+)"
        fi
        if [ -z "$reason" ]; then wt=""; continue; fi

        if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && [ "$FORCE" -eq 0 ]; then
          echo "skip   $wt  ($reason, dirty — --force で削除)"
          skipped=$((skipped + 1)); wt=""
          continue
        fi

        echo "remove $wt  ($reason, branch=${branch:-detached})"
        [ "$locked" -eq 1 ] && run git -C "$repo" worktree unlock "$wt"
        if run git -C "$repo" worktree remove --force "$wt"; then
          [ "$reason" = "merged" ] && [ -n "$branch" ] \
            && run git -C "$repo" branch -D "$branch" 2>/dev/null
          removed=$((removed + 1))
        fi
        wt=""
        ;;
    esac
  done < <(git -C "$repo" worktree list --porcelain 2>/dev/null; echo)
done

echo "---"
echo "removed=$removed skipped=$skipped$([ "$DRY_RUN" -eq 1 ] && echo ' (dry-run)')"
