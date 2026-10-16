#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2329
# dotfiles-sync の xdg_drift 記録が audit の成否と取り違えないことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/dotfiles-sync.nix"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

awk '
  index($0, "# 報告のみ") { active = 1 }
  active { print }
  active && $0 ~ /^    fi$/ { exit }
' "$source_nix" >"$tmp/body"
[ -s "$tmp/body" ]

run_case() {
  local verdict=$1
  (
    set -eu
    xdg_drift="not-run"
    nix() {
      case "$verdict" in
      none)
        printf '%s\n' "OK: XDG entries は宣言どおり" "drift=0"
        ;;
      drift)
        printf '%s\n' "drift あり" "drift=1"
        return 1
        ;;
      broken) return 1 ;;
      esac
    }
    source "$tmp/body"
    printf '%s' "$xdg_drift"
  )
}

check() {
  local verdict=$1 expected=$2 actual
  actual=$(run_case "$verdict")
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: audit=%s → xdg_drift=%s (expected %s)\n' "$verdict" "$actual" "$expected" >&2
    exit 1
  fi
}

check none none
check drift drift
check broken unknown

printf '%s\n' "ok: xdg_drift records none/drift/unknown without failing the sync"
