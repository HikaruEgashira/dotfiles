#!/bin/sh
input=$(cat)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
model_id=$(echo "$input" | jq -r '.model.id // ""')

# Git repo name
repo=$(basename "$(git -C "$dir" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)

# Git branch + status indicators
branch=$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
git_info=""
if [ -n "$branch" ]; then
  status_out=$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null)
  ind=""
  [ "$(echo "$status_out" | grep -c '^[MADRCU]')" -gt 0 ] && ind="${ind}+"
  [ "$(echo "$status_out" | grep -c '^ M\|^.M')" -gt 0 ] && ind="${ind}!"
  [ "$(echo "$status_out" | grep -c '^??')" -gt 0 ] && ind="${ind}?"
  [ -n "$ind" ] && ind=" [$ind]"
  git_info="$branch${ind}"
fi

# Worktree detection
wt=""
git_dir=$(git -C "$dir" --no-optional-locks rev-parse --git-dir 2>/dev/null)
case "$git_dir" in */.git/worktrees/*) wt=" wt" ;; esac

# Build output
parts=""
[ -n "$repo" ] && parts="$repo"
[ -n "$git_info" ] && parts="$parts  $git_info"
[ -n "$wt" ] && parts="$parts$wt"
parts="$parts | $model"
[ -n "$used" ] && parts="$parts | ctx:$(printf '%.0f' "$used")%"

# Cost estimation based on model pricing (USD per 1M tokens)
# haiku: in=$0.80 out=$4, sonnet: in=$3 out=$15, opus: in=$15 out=$75
case "$model_id" in
*haiku*)
  in_price=0.80
  out_price=4
  ;;
*opus*)
  in_price=15
  out_price=75
  ;;
*)
  in_price=3
  out_price=15
  ;;
esac
cost=$(awk "BEGIN { printf \"%.3f\", ($total_in * $in_price + $total_out * $out_price) / 1000000 }")
parts="$parts | \$$cost"

printf "%s" "$parts"
