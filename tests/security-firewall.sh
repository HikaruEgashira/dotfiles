#!/usr/bin/env bash
# shellcheck disable=SC1007,SC1091,SC2016,SC2329
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/darwin/security.nix"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

printf '%s\n' \
  '#!/bin/sh' \
  'case "${FIREWALL_TEST_MODE:-}" in' \
  '  getter-fail)' \
  '    case "${1:-}" in --get*) exit 1 ;; esac' \
  '    ;;' \
  '  incomplete)' \
  '    case "${1:-}" in --get*) printf "%s\n" "Firewall is enabled. (State = 1)" "Firewall stealth mode is on"; exit 0 ;; esac' \
  '    ;;' \
  '  off)' \
  '    case "${1:-}" in --get*) printf "%s\n" "Firewall is disabled. (State = 0)" "Firewall stealth mode is off" "Firewall has block all state set to disabled."; exit 0 ;; esac' \
  '    ;;' \
  '  on)' \
  '    case "${1:-}" in --get*) printf "%s\n" "Firewall is enabled. (State = 1)" "Firewall stealth mode is on" "Firewall is blocking all non-essential incoming connections."; exit 0 ;; esac' \
  '    ;;' \
  '  on-state2)' \
  '    case "${1:-}" in --get*) printf "%s\n" "Firewall is blocking all non-essential incoming connections. (State = 2)" "Firewall stealth mode is on" "Firewall is blocking all non-essential incoming connections."; exit 0 ;; esac' \
  '    ;;' \
  'esac' \
  'exit 0' \
  >"$tmp/socketfilterfw"
chmod +x "$tmp/socketfilterfw"

nix_quote="''"
sed -n "/networking.text = lib.mkAfter ${nix_quote}/,/^  ${nix_quote};$/p" "$source_nix" |
  sed '1d;$d' |
  sed -e "s#/usr/libexec/ApplicationFirewall/socketfilterfw#$tmp/socketfilterfw#g" \
    -e "s/''\${/\${/g" \
    >"$tmp/body"
[ -s "$tmp/body" ]

run_body() {
  local mode=$1
  (
    set -euo pipefail
    export FIREWALL_TEST_MODE=$mode
    source "$tmp/body"
  )
}

if run_body on; then :; else
  printf '%s\n' 'FAIL: enabled firewall posture was rejected' >&2
  exit 1
fi

if run_body on-state2; then :; else
  printf '%s\n' 'FAIL: block-all firewall posture (State = 2) was rejected' >&2
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

printf '%s\n' 'ok: firewall verification rejects OFF, incomplete, and failed read-back'
