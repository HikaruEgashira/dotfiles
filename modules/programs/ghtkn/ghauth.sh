#!/usr/bin/env bash
set -euo pipefail

# -f は既存 token と refresh token を revoke してから device flow をやり直す
force=
if [ "${1:-}" = "-f" ]; then
  force=1
  shift
fi

# launchd 常駐が落ちていても auth を止めない
if ! ghtkn info 2>/dev/null | jq -e '.agent.running' >/dev/null; then
  launchctl kickstart "gui/$UID/dev.egahika.ghtkn-agent" 2>/dev/null || true
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

# -p が one-time code を pbcopy し、device flow が入力ページをブラウザで開く
exec ghtkn auth -p "$@"
