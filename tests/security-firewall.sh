#!/usr/bin/env bash
# shellcheck disable=SC1007,SC1091,SC2016,SC2329
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/security.nix"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "${1:-}" = -n ]; then shift; fi' \
  'printf "%s\\n" "$*" >> "${FIREWALL_SUDO_LOG:?}"' \
  'exec "$@"' \
  >"$tmp/bin/sudo"
chmod +x "$tmp/bin/sudo"

printf '%s\n' \
  '#!/bin/sh' \
  'case "${FIREWALL_TEST_MODE:-}" in' \
  '  setter-fail)' \
  '    case "${1:-}" in --set*) exit 1 ;; esac' \
  '    ;;' \
  '  getter-fail)' \
  '    case "${1:-}" in --get*) exit 1 ;; esac' \
  '    ;;' \
  '  incomplete)' \
  '    case "${1:-}" in --get*) printf "%s\\n" "Firewall is enabled. (State = 1)" "Firewall stealth mode is on"; exit 0 ;; esac' \
  '    ;;' \
  '  off)' \
  '    case "${1:-}" in --get*) printf "%s\\n" "Firewall is disabled. (State = 0)" "Firewall stealth mode is off" "Firewall has block all state set to disabled."; exit 0 ;; esac' \
  '    ;;' \
  '  on)' \
  '    case "${1:-}" in --get*) printf "%s\\n" "Firewall is enabled. (State = 1)" "Firewall stealth mode is on" "Firewall is blocking all non-essential incoming connections."; exit 0 ;; esac' \
  '    ;;' \
  '  on-state2)' \
  '    case "${1:-}" in --get*) printf "%s\\n" "Firewall is blocking all non-essential incoming connections. (State = 2)" "Firewall stealth mode is on" "Firewall is blocking all non-essential incoming connections."; exit 0 ;; esac' \
  '    ;;' \
  'esac' \
  'exit 0' \
  >"$tmp/bin/socketfilterfw"
chmod +x "$tmp/bin/socketfilterfw"

nix_quote="''"
sed -n "/home.activation.firewall = /,/^  ${nix_quote};$/p" "$source_nix" |
  sed '1d;$d' |
  sed \
    -e "s#/usr/bin/sudo#$tmp/bin/sudo#g" \
    -e "s#/usr/libexec/ApplicationFirewall/socketfilterfw#$tmp/bin/socketfilterfw#g" \
    -e "s/''\${/\${/g" \
    >"$tmp/body"

run_body() {
  local mode=$1
  local dry_run=${2:-0}
  (
    set -euo pipefail
    export FIREWALL_TEST_MODE=$mode
    export FIREWALL_SUDO_LOG="$tmp/$mode.sudo.log"
    if [ "$dry_run" -eq 1 ]; then
      export DRY_RUN=1
    else
      unset DRY_RUN
    fi
    run() {
      if [ "$1" = --silence ] || [ "$1" = --quiet ]; then
        shift
      fi
      if [ -n "${DRY_RUN:-}" ]; then
        return 0
      fi
      "$@"
    }
    source "$tmp/body"
  )
}

if run_body on; then :; else
  printf '%s\n' 'FAIL: enabled firewall posture was rejected' >&2
  exit 1
fi

expected_sudo_calls=$(printf '%s\n' \
  "$tmp/bin/socketfilterfw --setglobalstate on" \
  "$tmp/bin/socketfilterfw --setstealthmode on" \
  "$tmp/bin/socketfilterfw --setblockall on")
if [ "$(cat "$tmp/on.sudo.log")" != "$expected_sudo_calls" ]; then
  printf '%s\n' 'FAIL: setter arguments changed' >&2
  exit 1
fi

if run_body on-state2; then :; else
  printf '%s\n' 'FAIL: block-all firewall posture (State = 2) was rejected' >&2
  exit 1
fi

if run_body setter-fail; then
  printf '%s\n' 'FAIL: setter failure was treated as success' >&2
  exit 1
fi

if run_body off; then
  printf '%s\n' 'FAIL: disabled read-back was treated as success' >&2
  exit 1
fi

if run_body getter-fail; then
  printf '%s\n' 'FAIL: getter failure was treated as success' >&2
  exit 1
fi

if run_body incomplete; then
  printf '%s\n' 'FAIL: incomplete read-back was treated as success' >&2
  exit 1
fi

if run_body setter-fail 1; then :; else
  printf '%s\n' 'FAIL: dry-run attempted to enforce live firewall state' >&2
  exit 1
fi

printf '%s\n' 'ok: firewall activation rejects setter failure and OFF read-back, and honors dry-run'
