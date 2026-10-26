#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2329
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/dotfiles-sync.nix"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

awk '
  index($0, "branch=$(git symbolic-ref --short HEAD") { active = 1 }
  active { print }
  active && index($0, "# 報告のみ") { exit }
' "$source_nix" >"$tmp/body"
[ -s "$tmp/body" ]

# ユーザー層の build 結果。activate の実行回数で適用を数える
mkdir -p "$tmp/home"
printf '#!/bin/sh\nprintf "activate\\n" >>"$SYNC_ACTIVATE_LOG"\n' >"$tmp/home/activate"
chmod +x "$tmp/home/activate"

run_sync() {
  local name=$1
  local branch=$2
  local dirty=$3
  local fail_first=$4
  local current=$5
  local git_log="$tmp/$name.git.log"
  local nix_log="$tmp/$name.nix.log"
  local first_marker="$tmp/$name.first"
  local pending_out="$tmp/$name.pending"
  (
    set -eu
    export SYNC_BRANCH=$branch
    export SYNC_DIRTY=$dirty
    export SYNC_FAIL_FIRST=$fail_first
    export SYNC_CURRENT=$current
    export SYNC_GIT_LOG=$git_log
    export SYNC_NIX_LOG=$nix_log
    export SYNC_FIRST_MARKER=$first_marker
    export SYNC_HOME=$tmp/home
    export SYNC_ACTIVATE_LOG=$tmp/$name.activate.log
    head_before=same
    head_after=$head_before
    outcome=error
    pending=unknown

    git() {
      printf '%s\n' "$*" >>"$SYNC_GIT_LOG"
      case "$1" in
      symbolic-ref) printf '%s\n' "$SYNC_BRANCH" ;;
      diff) [ "$SYNC_DIRTY" -eq 0 ] ;;
      fetch | pull) ;;
      rev-parse) printf '%s\n' same ;;
      *) return 1 ;;
      esac
    }

    nix() {
      printf '%s\n' "$*" >>"$SYNC_NIX_LOG"
      if [ "$SYNC_FAIL_FIRST" -eq 1 ] && [ ! -e "$SYNC_FIRST_MARKER" ]; then
        : >"$SYNC_FIRST_MARKER"
        return 1
      fi
      case "$*" in
      *homeConfigurations*) printf '%s\n' "$SYNC_HOME" ;;
      *) printf '%s\n' "/nix/store/built-system" ;;
      esac
    }

    readlink() {
      printf '%s\n' "$SYNC_CURRENT"
    }

    source "$tmp/body"
    printf '%s' "$pending" >"$pending_out"
  )
}

set +e
run_sync retry main 0 1 /nix/store/built-system
first_status=$?
set -e
if [ "$first_status" -eq 0 ]; then
  printf '%s\n' 'FAIL: first build failure was hidden' >&2
  exit 1
fi
set +e
run_sync retry main 0 1 /nix/store/built-system
second_status=$?
set -e
if [ "$second_status" -ne 0 ]; then
  printf '%s\n' 'FAIL: same-HEAD retry did not build' >&2
  exit 1
fi
# 1 回目は OS 層の build で失敗、2 回目は OS 層とユーザー層を build してユーザー層だけ適用する
[ "$(grep -c '^' "$tmp/retry.nix.log")" -eq 3 ]
[ "$(grep -c '^' "$tmp/retry.activate.log")" -eq 1 ]
[ "$(cat "$tmp/retry.pending")" = no ]
if grep -q '^pull ' "$tmp/retry.git.log"; then
  printf '%s\n' 'FAIL: same-HEAD retry pulled unnecessarily' >&2
  exit 1
fi

set +e
run_sync stale main 0 0 /nix/store/old-system
stale_status=$?
set -e
if [ "$stale_status" -ne 0 ]; then
  printf '%s\n' 'FAIL: stale generation check failed' >&2
  exit 1
fi
[ "$(cat "$tmp/stale.pending")" = yes ]

set +e
run_sync dirty main 1 0 /nix/store/built-system
dirty_status=$?
set -e
if [ "$dirty_status" -ne 0 ]; then
  printf '%s\n' 'FAIL: dirty tree guard failed' >&2
  exit 1
fi
[ ! -e "$tmp/dirty.nix.log" ]

set +e
run_sync nonmain feature 0 0 /nix/store/built-system
nonmain_status=$?
set -e
if [ "$nonmain_status" -ne 0 ]; then
  printf '%s\n' 'FAIL: non-main guard failed' >&2
  exit 1
fi
[ ! -e "$tmp/nonmain.nix.log" ]

printf '%s\n' 'ok: failed clean-main build retries; dirty and non-main trees skip; pending follows the live generation'
