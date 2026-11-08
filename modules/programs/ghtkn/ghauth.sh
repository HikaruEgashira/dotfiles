#!/usr/bin/env bash
set -euo pipefail

# -f は既存 token と refresh token を revoke してから device flow をやり直す
force=
if [ "${1:-}" = "-f" ]; then
  force=1
  shift
fi

# 常駐 (darwin: launchd / linux: systemd) が落ちていても auth を止めない
if ! ghtkn info 2>/dev/null | jq -e '.agent.running' >/dev/null; then
  if command -v launchctl >/dev/null; then
    launchctl kickstart "gui/$UID/dev.egahika.ghtkn-agent" 2>/dev/null || true
  else
    systemctl --user start ghtkn-agent 2>/dev/null || true
  fi
  for _ in {1..5}; do
    ghtkn info 2>/dev/null | jq -e '.agent.running' >/dev/null && break
    sleep 1
  done
fi

# refresh token は unlock 時にしか有効化できないので常に --enable-refresh を付ける
if ghtkn info 2>/dev/null | jq -e '.agent.locked' >/dev/null; then
  ghtkn agent unlock --enable-refresh
fi

# backend から消すには agent が unlocked である必要がある
if [ -n "$force" ]; then
  ghtkn revoke "$@" || echo "ghauth: revoke failed; continuing to auth" >&2
fi

# -p は one-time code を pbcopy するので darwin だけで付ける。linux では表示された code を手で入力する
if command -v pbcopy >/dev/null; then
  exec ghtkn auth -p "$@"
fi
exec ghtkn auth "$@"
