#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hook="$root/modules/programs/git/pre-commit.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
test_bin="$tmp/bin"
mkdir -p "$repo" "$test_bin"
git -C "$repo" init --quiet
ln -s "$(command -v git)" "$test_bin/git"
no_scanner_bin="$tmp/no-scanner-bin"
mkdir -p "$no_scanner_bin"
ln -s "$(command -v git)" "$no_scanner_bin/git"

local_hook_log="$tmp/local-hook.log"
cat >"$repo/.git/hooks/pre-commit" <<'HOOK'
#!/bin/sh
printf '%s\n' called >>"$LOCAL_HOOK_LOG"
HOOK
chmod +x "$repo/.git/hooks/pre-commit"

cat >"$test_bin/pleno-dlp" <<'SCANNER'
#!/bin/sh
printf '%s\n' "$*" >>"$DLP_CALLS_FILE"
printf '%s\n' "$DLP_OUTPUT"
exit "$DLP_EXIT"
SCANNER
chmod +x "$test_bin/pleno-dlp"

run_hook() {
  local expected_status=$1 expected_message=$2 status output
  shift 2
  set +e
  output=$(cd "$repo" && LOCAL_HOOK_LOG="$local_hook_log" DLP_CALLS_FILE="$tmp/dlp-calls" "$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -ne "$expected_status" ]; then
    printf 'FAIL: expected exit %s, got %s\n%s\n' "$expected_status" "$status" "$output" >&2
    exit 1
  fi
  if ! grep -Fq "$expected_message" <<<"$output"; then
    printf 'FAIL: expected output containing %s\n%s\n' "$expected_message" "$output" >&2
    exit 1
  fi
}

run_hook 0 "scan ok" /usr/bin/env PATH="$test_bin" DLP_EXIT=0 DLP_OUTPUT="scan ok" /bin/bash "$hook"
grep -Fxq 'hooks run git --fail-on high' "$tmp/dlp-calls"
grep -Fxq called "$local_hook_log"

rm -f "$local_hook_log" "$tmp/dlp-calls"
run_hook 1 "secret found" /usr/bin/env PATH="$test_bin" DLP_EXIT=1 DLP_OUTPUT="secret found" /bin/bash "$hook"
[ ! -e "$local_hook_log" ]

rm -f "$local_hook_log" "$tmp/dlp-calls"
run_hook 2 "refusing to continue" /usr/bin/env PATH="$test_bin" DLP_EXIT=2 DLP_OUTPUT="unknown flag" /bin/bash "$hook"
[ ! -e "$local_hook_log" ]

rm -f "$local_hook_log" "$tmp/dlp-calls"
run_hook 0 "not found on PATH" /usr/bin/env PATH="$no_scanner_bin" /bin/bash "$hook"
grep -Fxq called "$local_hook_log"

printf '%s\n' 'ok: pre-commit keeps the supported severity threshold, fails closed on scanner errors, and preserves the missing-tool escape hatch'
