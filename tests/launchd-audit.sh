#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/launchd-audit.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
known=${1:-dev.egahika.ssh-agent}
wrapper=${2:-}
printf '%s\n' "$known" >"$tmp/known-labels"

cat >"$tmp/fake-uname" <<'MOCK'
#!/bin/sh
[ "$#" -eq 1 ] && [ "$1" = -s ] || exit 64
printf '%s\n' "${LAUNCHD_AUDIT_TEST_OS:-Darwin}"
MOCK
cat >"$tmp/fake-date" <<'MOCK'
#!/bin/sh
[ "$#" -eq 2 ] && [ "$1" = -u ] && [ "$2" = +%FT%TZ ] || exit 64
printf '%s\n' '2026-10-30T00:00:00Z'
MOCK
cat >"$tmp/fake-launchctl" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" >"$launchdAuditTestTmp/launchctl-args"
[ "$#" -eq 1 ] && [ "$1" = list ] || exit 64
case "$LAUNCHD_AUDIT_MODE" in
  fail)
    printf '%s\n' 'partial inventory must not be trusted'
    exit 42
    ;;
  blank)
    exit 0
    ;;
  empty)
    printf ' \tPID   Status\tLabel \n'
    ;;
  malformed)
    printf 'PID State Label\n'
    ;;
  headerless)
    printf '123 0 com.example.unexpected\n'
    ;;
  large)
    printf 'PID Status Label\n'
    i=0
    while [ "$i" -lt 12000 ]; do
      printf '1 0 com.apple.fixture.%s\n' "$i"
      i=$((i + 1))
    done
    ;;
  known)
    printf 'PID Status Label\n'
    while IFS= read -r label; do
      [ -n "$label" ] && printf '1 0 %s\n' "$label"
    done <"$launchdAuditTestTmp/known-labels"
    ;;
  unknown)
    printf 'PID Status Label\n1 0 com.example.unexpected\n'
    ;;
  *)
    exit 65
    ;;
esac
MOCK
chmod +x "$tmp/fake-uname" "$tmp/fake-date" "$tmp/fake-launchctl"

export launchdAuditTestTmp="$tmp"
if [[ -n "$wrapper" ]]; then
  # Keep these variable references literal until the generated wrapper runs.
  # shellcheck disable=SC2016
  sed \
    -e 's|/nix/store/[^ ]*/bin/uname|"$launchdAuditTestTmp/fake-uname"|g' \
    -e 's|/nix/store/[^ ]*/bin/date|"$launchdAuditTestTmp/fake-date"|g' \
    -e 's|/nix/store/[^ ]*/bin/bash|/bin/bash|g' \
    -e 's|/bin/launchctl|"$launchdAuditTestTmp/fake-launchctl"|g' \
    "$wrapper" >"$tmp/wrapper"
  chmod +x "$tmp/wrapper"
  wrapper="$tmp/wrapper"
  bash -n "$wrapper"
  run_audit() { LAUNCHD_AUDIT_MODE=$1 bash "$wrapper"; }
  assert_list_argv() { [[ $(cat "$tmp/launchctl-args") == list ]]; }
else
  run_audit() {
    LAUNCHD_AUDIT_MODE=$1 bash "$root/scripts/launchd-audit.sh" \
      "$known" "$tmp/fake-launchctl" "$root/scripts/check-launchd-labels.sh"
  }
  assert_list_argv() { [[ $(cat "$tmp/launchctl-args") == list ]]; }
fi

expect_failure() {
  local mode=$1 expected_status=$2 expected_message=$3 output status
  if output=$(run_audit "$mode" 2>&1); then
    printf 'FAIL: inventory mode %s was accepted\n' "$mode" >&2
    exit 1
  else
    status=$?
  fi
  [[ $status -eq $expected_status ]]
  [[ $output == *"$expected_message"* ]]
  [[ $output != *'partial inventory'* ]]
  assert_list_argv
}

expect_failure fail 2 'launchd-audit: unable to enumerate the launchd user domain'
expect_failure blank 2 'launchd-audit: invalid launchd list header'
expect_failure malformed 2 'launchd-audit: invalid launchd list header'
expect_failure headerless 2 'launchd-audit: invalid launchd list header'

output=$(run_audit empty)
[[ $output == *'OK: no unexpected third-party launchd agents' ]]
assert_list_argv

output=$(run_audit large)
[[ $output == *'OK: no unexpected third-party launchd agents' ]]
assert_list_argv

output=$(run_audit known)
[[ $output == *'OK: no unexpected third-party launchd agents' ]]
assert_list_argv

if output=$(run_audit unknown 2>&1); then
  printf '%s\n' 'FAIL: unknown label was accepted' >&2
  exit 1
else
  status=$?
fi
[[ $status -eq 1 ]]
[[ $output == *'UNKNOWN  com.example.unexpected'* ]]
assert_list_argv

if [[ -n "$wrapper" ]]; then
  output=$(LAUNCHD_AUDIT_TEST_OS=Linux LAUNCHD_AUDIT_MODE=empty "$wrapper")
  [[ $output == 'launchd-audit: macOS only; skipping' ]]
fi

printf '%s\n' 'ok: generated wrapper syntax/argv and fail-closed, empty, known, unknown inventories pass'
