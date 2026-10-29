#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Load only this stage: the script's top-level ladder performs real cleanup.
eval "$(sed -n '/^step_podman() {/,/^}/p' "$root/scripts/disk-maintenance.sh")"
export PODMAN_MACHINE=test-machine
export CACHE_AGE_DAYS=30
DRY_RUN=0
podman() {
  case "$1 $2" in
  'machine inspect')
    [ "$state" != unavailable ] || return 1
    printf '%s\n' "$state"
    ;;
  'machine rm') printf '%s\n' "$*" >>"$tmp/deletions" ;;
  *) return 1 ;;
  esac
}
date() { return 1; }
run() {
  if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
  "$@"
}
for state in running starting unknown '' unavailable; do
  if step_podman; then
    echo "FAIL: accepted state '$state'" >&2
    exit 1
  fi
  [ ! -e "$tmp/deletions" ]
done
state=stopped
DRY_RUN=1
step_podman
[ ! -e "$tmp/deletions" ]
DRY_RUN=0
step_podman
[ "$(cat "$tmp/deletions")" = 'machine rm --force test-machine' ]
echo 'OK: only confirmed stopped machines reach deletion; dry-run preserves them'
