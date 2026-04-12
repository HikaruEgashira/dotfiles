#!/bin/bash
# Claude Code オーケストレーター レイアウト
# Usage: tmux-dev [project-dir]
#
# ┌────────────┬─────────────────┐
# │            │                 │
# │  shell     │  Claude Code    │
# │  確認用    │  (orchestrator) │
# │            │                 │
# └────────────┴─────────────────┘

dir="${1:-.}"
dir="$(cd "$dir" && pwd)"

session="dev-$(basename "$dir")"

# 既存セッションがあればアタッチ
if tmux has-session -t "$session" 2>/dev/null; then
  tmux attach -t "$session"
  exit 0
fi

# 左: 手元確認用shell
tmux new-session -d -s "$session" -c "$dir"

# 右: Claude Code
tmux split-window -h -t "$session" -c "$dir" -l 60%
tmux send-keys -t "$session:.2" "claude" Enter

# 左ペインにフォーカス（手元操作用）
tmux select-pane -t "$session:.1"

tmux attach -t "$session"
