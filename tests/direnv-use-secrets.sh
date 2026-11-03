#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stdlib="$root/modules/programs/direnv/use_secrets.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# age を stub し、復号結果の代わりに平文ファイルを返す。鍵も env.age も中身は見ない
mkdir -p "$tmp/bin" "$tmp/home/.config/secrets"
cat >"$tmp/bin/age" <<'AGE'
#!/bin/sh
[ "$1" = "-d" ] && [ "$2" = "-i" ] && [ -r "$3" ] && [ -r "$4" ] || exit 1
cat "$4.plain"
AGE
chmod +x "$tmp/bin/age"
: >"$tmp/home/.config/secrets/age-se.txt"
: >"$tmp/home/.config/secrets/env.age"
cat >"$tmp/home/.config/secrets/env.age.plain" <<'PLAIN'
# comment
ALPHA=a
FLATT_GUARD_TOKEN=tok

BETA=b=c
PLAIN

# direnv stdlib の log_error だけ stub し、関数を素の bash で呼ぶ
cat >"$tmp/harness.sh" <<'HARNESS'
log_error() { printf '%s\n' "$*" >&2; }
. "$1"
shift
use_secrets "$@"
status=$?
env | grep -E '^(ALPHA|BETA|FLATT_GUARD_TOKEN|UV_INDEX_URL)=' | sort
exit "$status"
HARNESS

run_case() {
  local name=$1 expected_status=$2 expected_env=$3 status output
  shift 3
  set +e
  output=$(cd "$tmp" && env -i HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$tmp/harness.sh" "$stdlib" "$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -ne "$expected_status" ]; then
    printf 'FAIL: %s: expected exit %s, got %s\n%s\n' "$name" "$expected_status" "$status" "$output" >&2
    exit 1
  fi
  if [ "$(printf '%s\n' "$output" | grep -E '^[A-Z_]+=' || true)" != "$expected_env" ]; then
    printf 'FAIL: %s: unexpected environment\n%s\n' "$name" "$output" >&2
    exit 1
  fi
}

run_case "no args exports every key" 0 "$(
  cat <<'EOF'
ALPHA=a
BETA=b=c
FLATT_GUARD_TOKEN=tok
UV_INDEX_URL=https://token:tok@pypi.flatt.tech/simple/
EOF
)"

run_case "selected key only" 0 "ALPHA=a" ALPHA

run_case "value may contain =" 0 "BETA=b=c" BETA

run_case "FLATT_GUARD_TOKEN derives UV_INDEX_URL" 0 "$(
  cat <<'EOF'
FLATT_GUARD_TOKEN=tok
UV_INDEX_URL=https://token:tok@pypi.flatt.tech/simple/
EOF
)" FLATT_GUARD_TOKEN

run_case "missing key fails but present keys are exported" 1 "ALPHA=a" ALPHA NOPE

rm "$tmp/home/.config/secrets/age-se.txt"
run_case "missing key file fails without calling age" 1 "" ALPHA

echo "direnv-use-secrets: ok"
