#!/bin/bash
# Usage: tdev [project-dir]       create/attach session
#        tdev kill [project-dir]  kill session
# Pane splits are driven by Claude Agent Teams (teammateMode=tmux).

if [[ $1 == "kill" ]]; then
  dir="${2:-.}"
  dir="$(cd "$dir" && pwd)"
  session="dev-$(basename "$dir")"
  tmux kill-session -t "$session" 2>/dev/null && echo "killed: $session" || echo "no session: $session"
  exit 0
fi

dir="${1:-.}"
dir="$(cd "$dir" && pwd)"

session="dev-$(basename "$dir")"

if tmux has-session -t "$session" 2>/dev/null; then
  tmux attach -t "$session"
  exit 0
fi

tmux new-session -d -s "$session" -c "$dir"

tmux send-keys -t "$session" "claude" Enter

tmux attach -t "$session"
