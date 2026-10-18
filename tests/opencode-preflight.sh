#!/usr/bin/env bash
# shellcheck disable=SC1091
# opencode preflight が stale service.json + orphan LISTEN を検出して自己修復することを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
preflight="$root/modules/programs/opencode/preflight.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/home/.local/state/opencode"

# lsof は LISTEN 中の pid を返す。orphan が死ぬと何も返さず port 解放を模す
cat >"$tmp/bin/lsof" <<'EOF'
#!/bin/sh
[ -n "${OPENCODE_TEST_LISTEN_PID:-}" ] || exit 1
kill -0 "$OPENCODE_TEST_LISTEN_PID" 2>/dev/null || exit 1
printf '%s\n' "$OPENCODE_TEST_LISTEN_PID"
EOF
chmod +x "$tmp/bin/lsof"

# opencode は port が埋まっている間 bind に失敗する (無言ハングのモデル)
cat >"$tmp/bin/opencode" <<'EOF'
#!/bin/sh
printf '%s\n' "opencode $*" >>"${OPENCODE_TEST_LOG:?}"
case "${1:-}" in
service) exit 0 ;;
esac
if [ -n "${OPENCODE_TEST_LISTEN_PID:-}" ] && kill -0 "$OPENCODE_TEST_LISTEN_PID" 2>/dev/null; then
  printf '%s\n' "Managed service port 49374 on 127.0.0.1 is already in use" >>"$OPENCODE_TEST_LOG"
  exit 1
fi
printf '%s\n' "tui-started" >>"$OPENCODE_TEST_LOG"
EOF
chmod +x "$tmp/bin/opencode"

write_state() {
  printf '{"pid":%s,"port":49374}\n' "$1" >"$HOME/.local/state/opencode/service.json"
}

start_dead_pid() {
  local p
  sleep 300 &
  p=$!
  kill -9 "$p" 2>/dev/null || true
  wait "$p" 2>/dev/null || true
  printf '%s' "$p"
}

run_disabled() {
  (
    set -euo pipefail
    export HOME="$tmp/home" XDG_STATE_HOME= PATH="$tmp/bin:$PATH" OPENCODE_TEST_LOG="$tmp/disabled.log"
    : >"$OPENCODE_TEST_LOG"
    sleep 300 &
    local orphan=$!
    export OPENCODE_TEST_LISTEN_PID=$orphan
    write_state "$(start_dead_pid)"

    set +e
    opencode --version
    local status=$?
    set -e

    kill "$orphan" 2>/dev/null || true
    wait "$orphan" 2>/dev/null || true

    if [ "$status" -eq 0 ]; then
      printf '%s\n' "FAIL: stale orphan was not observed without preflight" >&2
      return 1
    fi
    grep -q "already in use" "$OPENCODE_TEST_LOG" || {
      printf '%s\n' "FAIL: bind-failure hang was not reproduced" >&2
      return 1
    }
  )
}

run_enabled() {
  (
    set -euo pipefail
    export HOME="$tmp/home" XDG_STATE_HOME= PATH="$tmp/bin:$PATH" OPENCODE_TEST_LOG="$tmp/enabled.log"
    : >"$OPENCODE_TEST_LOG"
    sleep 300 &
    local orphan=$!
    export OPENCODE_TEST_LISTEN_PID=$orphan
    write_state "$(start_dead_pid)"

    source "$preflight"
    opencode --version

    if kill -0 "$orphan" 2>/dev/null; then
      kill "$orphan" 2>/dev/null || true
      printf '%s\n' "FAIL: preflight left the orphan alive" >&2
      return 1
    fi
    grep -q "opencode service restart" "$OPENCODE_TEST_LOG" || {
      printf '%s\n' "FAIL: preflight did not restart the service" >&2
      return 1
    }
    grep -q "tui-started" "$OPENCODE_TEST_LOG" || {
      printf '%s\n' "FAIL: preflight did not let the TUI start" >&2
      return 1
    }
  )
}

run_healthy() {
  (
    set -euo pipefail
    export HOME="$tmp/home" XDG_STATE_HOME= PATH="$tmp/bin:$PATH" OPENCODE_TEST_LOG="$tmp/healthy.log"
    : >"$OPENCODE_TEST_LOG"
    sleep 300 &
    local live=$!
    export OPENCODE_TEST_LISTEN_PID=$live
    write_state "$live"

    source "$preflight"
    _opencode_preflight

    if ! kill -0 "$live" 2>/dev/null; then
      printf '%s\n' "FAIL: preflight killed a healthy service" >&2
      return 1
    fi
    kill "$live" 2>/dev/null || true
    wait "$live" 2>/dev/null || true

    if grep -q "service restart" "$OPENCODE_TEST_LOG"; then
      printf '%s\n' "FAIL: preflight restarted a healthy service" >&2
      return 1
    fi
  )
}

run_disabled
run_enabled
run_healthy

printf '%s\n' "ok: preflight recovers a stale listener and leaves a healthy service alone"
