#!/usr/bin/env bash
# ai-sandbox の AWS CLI wrapper が sandbox 制限だけを通知し、通常実行・引数・終了コードを変えないことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/ai-sandbox.nix"
tmp=$(mktemp -d)
trap 'chmod 700 "$tmp/denied/.aws" 2>/dev/null || true; rm -rf "$tmp"' EXIT

nix_quote="''"
start="  awsWrapper = pkgs.writeShellScript \"aws-sandbox\" ${nix_quote}"
end="  ${nix_quote};"
awk -v start="$start" -v end="$end" '
  $0 == start { active = 1; next }
  active && $0 == end { exit }
  active { print }
' "$source_nix" >"$tmp/wrapper.nix"
[ -s "$tmp/wrapper.nix" ]

sed \
  -e "s/''\${/\${/g" \
  -e "s#^    real=.*#    real=$tmp/bin/aws#" \
  "$tmp/wrapper.nix" >"$tmp/aws-wrapper"
chmod +x "$tmp/aws-wrapper"

mkdir -p "$tmp/bin" "$tmp/home/.aws" "$tmp/noaws" "$tmp/denied/.aws"
printf '%s\n' '[default]' >"$tmp/home/.aws/config"
chmod 000 "$tmp/denied/.aws"

cat >"$tmp/bin/aws" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${AWS_TEST_LOG:?}"
printf '%s\n' 'fake-aws stdout'
exit "${AWS_TEST_EXIT:-0}"
EOF
chmod +x "$tmp/bin/aws"

assert_silent_normal() {
  local name=$1 home=$2
  set +e
  HOME="$home" AWS_TEST_LOG="$tmp/$name.log" "$tmp/aws-wrapper" --region ap-northeast-1 --output json \
    >"$tmp/$name.out" 2>"$tmp/$name.err"
  local status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "FAIL: ${name}: normal execution exited ${status}" >&2
    exit 1
  fi
  if [ -s "$tmp/$name.err" ]; then
    printf '%s\n' "FAIL: ${name}: normal execution printed to stderr" >&2
    cat "$tmp/$name.err" >&2
    exit 1
  fi
}

assert_silent_normal readable "$tmp/home"
assert_silent_normal missing "$tmp/noaws"

if [ "$(cat "$tmp/readable.log")" != "--region ap-northeast-1 --output json" ]; then
  printf '%s\n' 'FAIL: wrapper changed AWS CLI arguments' >&2
  exit 1
fi
if [ "$(cat "$tmp/readable.out")" != "fake-aws stdout" ]; then
  printf '%s\n' 'FAIL: wrapper changed AWS CLI stdout' >&2
  exit 1
fi

set +e
HOME="$tmp/home" CLAUDE_CODE_SANDBOXED=1 AWS_TEST_LOG="$tmp/sandbox.log" AWS_TEST_EXIT=7 \
  "$tmp/aws-wrapper" --profile hikae-admin-sso sts get-caller-identity \
  >"$tmp/sandbox.out" 2>"$tmp/sandbox.err"
sandbox_status=$?
set -e

if [ "$sandbox_status" -ne 7 ]; then
  printf '%s\n' "FAIL: wrapper did not preserve AWS CLI exit code (got ${sandbox_status})" >&2
  exit 1
fi
if [ "$(cat "$tmp/sandbox.log")" != "--profile hikae-admin-sso sts get-caller-identity" ]; then
  printf '%s\n' 'FAIL: wrapper changed sandboxed AWS CLI arguments' >&2
  exit 1
fi
if ! grep -Fq '.aws' "$tmp/sandbox.err" || ! grep -Fq 'sandbox' "$tmp/sandbox.err" || ! grep -Fq 'SSO' "$tmp/sandbox.err"; then
  printf '%s\n' 'FAIL: sandbox restriction notice is missing or incomplete' >&2
  cat "$tmp/sandbox.err" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  set +e
  HOME="$tmp/denied" AWS_TEST_LOG="$tmp/denied.log" "$tmp/aws-wrapper" --version \
    >"$tmp/denied.out" 2>"$tmp/denied.err"
  denied_status=$?
  set -e
  if [ "$denied_status" -ne 0 ]; then
    printf '%s\n' "FAIL: unreadable ~/.aws changed the exit code (got ${denied_status})" >&2
    exit 1
  fi
  if ! grep -Fq '.aws' "$tmp/denied.err" || ! grep -Fq 'sandbox' "$tmp/denied.err"; then
    printf '%s\n' 'FAIL: unreadable ~/.aws did not produce the sandbox notice' >&2
    cat "$tmp/denied.err" >&2
    exit 1
  fi
fi

printf '%s\n' 'ok: aws wrapper is silent normally and explains sandboxed ~/.aws denial without changing args or status'
