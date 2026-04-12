#!/bin/bash
# Claude Code Agent Teams レイアウト
# Usage: tdev [project-dir]    セッション作成 or アタッチ
#        tdev kill [project-dir] セッション終了
#
# tmux セッション内で claude を起動する。
# teammateMode=tmux により、Agent Teams が自動でペイン分割を管理する。

if [[ "$1" == "kill" ]]; then
  dir="${2:-.}"
  dir="$(cd "$dir" && pwd)"
  session="dev-$(basename "$dir")"
  tmux kill-session -t "$session" 2>/dev/null && echo "killed: $session" || echo "no session: $session"
  exit 0
fi

dir="${1:-.}"
dir="$(cd "$dir" && pwd)"

session="dev-$(basename "$dir")"

# 既存セッションがあればアタッチ
if tmux has-session -t "$session" 2>/dev/null; then
  tmux attach -t "$session"
  exit 0
fi

tmux new-session -d -s "$session" -c "$dir"

tmux send-keys -t "$session" "claude" Enter

tmux attach -t "$session"
