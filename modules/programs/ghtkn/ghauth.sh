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
    launchctl kickstart "gui/$UID/${GHTKN_AGENT_LABEL:-dev.egahika.ghtkn-agent}" 2>/dev/null || true
  else
    systemctl --user start ghtkn-agent 2>/dev/null || true
  fi
  for _ in {1..5}; do
    ghtkn info 2>/dev/null | jq -e '.agent.running' >/dev/null && break
    sleep 1
  done
fi

# refresh token は unlock 時にしか有効化できないので darwin では --enable-refresh を付ける。
# linux (WSL) は passwordless sudo と Windows 側の `wsl.exe -u root` で root が容易に取れるため、
# ghtkn の refresh-token docs に従い有効化しない (8h 毎に device flow をやり直す)
if ghtkn info 2>/dev/null | jq -e '.agent.locked' >/dev/null; then
  if command -v launchctl >/dev/null; then
    ghtkn agent unlock --enable-refresh
  else
    ghtkn agent unlock
  fi
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
