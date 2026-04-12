#!/bin/bash
# Claude Code オーケストレーター レイアウト
# Usage: tmux-dev [project-dir]
#
# ┌────────┬──────┬──────┬──────┬──────┐
# │        │ cc1  │ cc2  │ cc3  │ cc4  │
# │ shell  │      │      │      │      │
# │        │      │      │      │      │
# └────────┴──────┴──────┴──────┴──────┘

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

# 右: Claude Code 1
tmux split-window -h -t "$session" -c "$dir" -l 80%
tmux send-keys -t "$session:.2" "claude" Enter

# Claude Code 2
tmux split-window -h -t "$session:.2" -c "$dir" -l 75%
tmux send-keys -t "$session:.3" "claude" Enter

# Claude Code 3
tmux split-window -h -t "$session:.3" -c "$dir" -l 66%
tmux send-keys -t "$session:.4" "claude" Enter

# Claude Code 4
tmux split-window -h -t "$session:.4" -c "$dir" -l 50%
tmux send-keys -t "$session:.5" "claude" Enter

# 左ペインにフォーカス
tmux select-pane -t "$session:.1"

tmux attach -t "$session"
