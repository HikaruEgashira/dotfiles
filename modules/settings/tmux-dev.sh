#!/bin/bash
# Claude Code オーケストレーター レイアウト
# Usage: tmux-dev [project-dir]
#
# ┌──────────────────────────────┐
# │                              │
# │  Claude Code (orchestrator)  │
# │                              │
# ├──────────────────────────────┤
# │  手元確認用 shell (20%)      │
# └──────────────────────────────┘

dir="${1:-.}"
dir="$(cd "$dir" && pwd)"

session="dev-$(basename "$dir")"

# 既存セッションがあればアタッチ
if tmux has-session -t "$session" 2>/dev/null; then
  tmux attach -t "$session"
  exit 0
fi

# 上: Claude Code
tmux new-session -d -s "$session" -c "$dir"

# 下: 手元確認用
tmux split-window -v -t "$session" -c "$dir" -l 20%

# 上ペインにフォーカスしてClaude Code起動
tmux select-pane -t "$session:.1"
tmux send-keys -t "$session:.1" "claude" Enter

tmux attach -t "$session"
