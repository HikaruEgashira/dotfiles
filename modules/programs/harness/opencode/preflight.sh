#!/usr/bin/env bash
# service.json の pid は死んでいるのに port が LISTEN のまま残ると TUI が無言でハングする

_opencode_port="${OPENCODE_SERVICE_PORT:-49374}"
_opencode_repaired=0

_opencode_state_file() {
  printf '%s/opencode/service.json\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

_opencode_recorded_pid() {
  local state
  state=$(_opencode_state_file)
  [ -r "$state" ] || return 1
  sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$state" | head -n1
}

_opencode_listener_pids() {
  lsof -nP -t -iTCP:"$_opencode_port" -sTCP:LISTEN 2>/dev/null || true
}

_opencode_listener_pid() {
  _opencode_listener_pids | head -n1
}

_opencode_pid_running() {
  local stat
  kill -0 "$1" 2>/dev/null || return 1
  stat=$(ps -o stat= -p "$1" 2>/dev/null) || return 1
  [ -n "$stat" ] || return 1
  case "$stat" in
  Z*) return 1 ;;
  esac
  return 0
}

_opencode_orphan_pids() {
  local recorded pid found=0
  recorded=$(_opencode_recorded_pid) || recorded=""
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if [ "$pid" = "$recorded" ] && _opencode_pid_running "$pid"; then
      continue
    fi
    found=1
    printf '%s\n' "$pid"
  done <<EOF
$(_opencode_listener_pids)
EOF
  [ "$found" -eq 1 ]
}

_opencode_orphan_pid() {
  local pids
  pids=$(_opencode_orphan_pids) || return 1
  [ -n "$pids" ] || return 1
  printf '%s\n' "$pids" | head -n1
}

_opencode_wait_for_exit() {
  local limit="$1" waits=0 pid alive
  shift
  while [ "$waits" -lt "$limit" ]; do
    alive=0
    for pid in "$@"; do
      if _opencode_pid_running "$pid"; then
        alive=1
      fi
    done
    [ "$alive" -eq 0 ] && return 0
    sleep 0.1
    waits=$((waits + 1))
  done
  return 1
}

_opencode_preflight() {
  local -a orphans=()
  local pid
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    orphans+=("$pid")
  done <<EOF
$(_opencode_orphan_pids)
EOF
  [ "${#orphans[@]}" -gt 0 ] || return 0

  for pid in "${orphans[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  if ! _opencode_wait_for_exit 50 "${orphans[@]}"; then
    # orphan が SIGTERM を無視しても port を解放させる
    for pid in "${orphans[@]}"; do
      kill -9 "$pid" 2>/dev/null || true
    done
    _opencode_wait_for_exit 20 "${orphans[@]}" || true
  fi

  for pid in "${orphans[@]}"; do
    if _opencode_pid_running "$pid"; then
      printf 'opencode: stale service pid %s survived SIGKILL (port %s)\n' "$pid" "$_opencode_port" >&2
      return 1
    fi
  done

  printf 'opencode: removed stale service on port %s (pid %s)\n' \
    "$_opencode_port" "${orphans[*]}" >&2
  command opencode service restart >/dev/null 2>&1 || true
  _opencode_repaired=1
}

_opencode_health() {
  _opencode_repaired=0
  if ! _opencode_preflight; then
    printf '%s opencode: service repair failed (port %s)\n' \
      "$(date -u +%FT%TZ)" "$_opencode_port" >&2
    return 1
  fi
  if [ "$_opencode_repaired" -eq 1 ]; then
    printf '%s opencode: service repaired\n' "$(date -u +%FT%TZ)"
  else
    printf '%s opencode: service healthy\n' "$(date -u +%FT%TZ)"
  fi
}

_opencode_run() {
  _opencode_preflight || {
    printf 'opencode: service repair failed; see docs/operations.md §4.5\n' >&2
    return 1
  }
  command "$@"
}

opencode() {
  _opencode_run opencode "$@"
}

opencode2() {
  _opencode_run opencode2 "$@"
}

if [ -z "${ZSH_VERSION:-}" ] && [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  _opencode_health
fi
