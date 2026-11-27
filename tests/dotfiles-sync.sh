#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2329
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/dotfiles-sync.nix"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

awk '
  index($0, "head_before=$(cat") { active = 1 }
  active { print }
  active && index($0, "# 報告のみ") { exit }
' "$source_nix" | sed "s#\${metricsDir}#$tmp/metrics#g" >"$tmp/body"
[ -s "$tmp/body" ]
mkdir -p "$tmp/metrics"

# ~/dotfiles の checkout は sandbox から書けるので、sync は checkout の git を一切実行しない
if grep -Eq 'git (-C|fetch|pull|diff|symbolic-ref|merge)|cd "\$HOME/dotfiles"|"\.#' "$tmp/body"; then
  printf '%s\n' 'FAIL: dotfiles-sync reads the writable ~/dotfiles checkout' >&2
  exit 1
fi

mkdir -p "$tmp/home"
cat >"$tmp/home/activate" <<'EOF'
#!/bin/sh
printf 'activate\n' >>"$SYNC_ACTIVATE_LOG"
EOF
chmod +x "$tmp/home/activate"

sha=0123456789abcdef0123456789abcdef01234567

run_sync() {
  local name=$1 remote=$2 current=$3
  (
    set -eu
    export SYNC_REMOTE=$remote SYNC_HOME=$tmp/home SYNC_ACTIVATE_LOG=$tmp/$name.activate.log
    export SYNC_NIX_LOG=$tmp/$name.nix.log SYNC_CURRENT=$current
    outcome=error
    pending=unknown
    git() {
      case "$*" in
      "ls-remote https://github.com/HikaruEgashira/dotfiles refs/heads/main") printf '%s\trefs/heads/main\n' "$SYNC_REMOTE" ;;
      *) return 1 ;;
      esac
    }
    nix() {
      printf '%s\n' "$*" >>"$SYNC_NIX_LOG"
      case "$*" in
      *homeConfigurations*) printf '%s\n' "$SYNC_HOME" ;;
      *) printf '%s\n' /nix/store/built-system ;;
      esac
    }
    readlink() { printf '%s\n' "$SYNC_CURRENT"; }
    source "$tmp/body"
    printf '%s' "$pending" >"$tmp/$name.pending"
  )
}

run_sync ok "$sha" /nix/store/built-system
grep -q "github:HikaruEgashira/dotfiles/$sha#darwinConfigurations" "$tmp/ok.nix.log"
grep -q "github:HikaruEgashira/dotfiles/$sha#homeConfigurations" "$tmp/ok.nix.log"
[ "$(grep -c '^' "$tmp/ok.activate.log")" -eq 1 ]
[ "$(cat "$tmp/ok.pending")" = no ]
[ "$(cat "$tmp/metrics/applied")" = "$sha" ]

run_sync stale "$sha" /nix/store/old-system
[ "$(cat "$tmp/stale.pending")" = yes ]

run_sync noorigin "" /nix/store/built-system | grep -q 'skip: cannot resolve origin main'
[ ! -e "$tmp/noorigin.nix.log" ]

printf '%s\n' 'ok: dotfiles-sync builds the pinned origin main commit and never the local checkout'
