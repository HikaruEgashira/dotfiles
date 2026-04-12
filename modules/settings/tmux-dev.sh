#!/bin/bash
# Claude Code オーケストレーター レイアウト
# Usage: tmux-dev [project-dir]
#
# ┌────────┬─────────────────────┐
# │        │  Claude Code 1      │
# │ shell  ├─────────────────────┤
# │        │  Claude Code 2      │
# └────────┴─────────────────────┘

dir="${1:-.}"
dir="$(cd "$dir" && pwd)"

session="dev-$(basename "$dir")"

# 既存セッションがあればアタッチ
if tmux has-session -t "$session" 2>/dev/null; then
  tmux attach -t "$session"
  exit 0
fi

# pane 1: shell（左）
tmux new-session -d -s "$session" -c "$dir"

# pane 2: 右側を作る
tmux split-window -h -t "$session:1.1" -c "$dir" -l 80%

# pane 3: 右を縦分割
tmux split-window -v -t "$session:1.2" -c "$dir" -l 50%

# Claude Code を各ペインで起動
tmux send-keys -t "$session:1.2" "claude" Enter
tmux send-keys -t "$session:1.3" "claude" Enter

# shellペインにフォーカス
tmux select-pane -t "$session:1.1"

tmux attach -t "$session"
