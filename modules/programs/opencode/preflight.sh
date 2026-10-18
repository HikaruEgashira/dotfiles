# shellcheck shell=bash
# service.json の pid は死んでいるのに port が LISTEN のまま残ると TUI が無言でハングする

_opencode_port="${OPENCODE_SERVICE_PORT:-49374}"

_opencode_recorded_pid() {
  local state
  state="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/service.json"
  [ -r "$state" ] || return 1
  sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$state" | head -n1
}

_opencode_listener_pid() {
  lsof -nP -t -iTCP:"$_opencode_port" -sTCP:LISTEN 2>/dev/null | head -n1
}

_opencode_orphan_pid() {
  local listener recorded
  listener=$(_opencode_listener_pid) || listener=""
  [ -n "$listener" ] || return 1
  recorded=$(_opencode_recorded_pid) || recorded=""
  if [ "$recorded" = "$listener" ] && kill -0 "$recorded" 2>/dev/null; then
    return 1
  fi
  printf '%s\n' "$listener"
}

_opencode_preflight() {
  local orphan listener waits=0
  orphan=$(_opencode_orphan_pid) || return 0
  kill "$orphan" 2>/dev/null || true
  while [ "$waits" -lt 50 ]; do
    listener=$(_opencode_listener_pid) || listener=""
    [ -n "$listener" ] || break
    sleep 0.1
    waits=$((waits + 1))
  done
  command opencode service restart >/dev/null 2>&1 || true
}

opencode() {
  _opencode_preflight
  command opencode "$@"
}

opencode2() {
  _opencode_preflight
  command opencode2 "$@"
}
