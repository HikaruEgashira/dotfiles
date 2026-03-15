typeset -g AI_JP_RATIO_THRESHOLD=0.35
typeset -g AI_MIN_LEN=6

_ai_jp_len() {
  local s="$1"
  local jp_only
  jp_only=$(print -r -- "$s" | perl -CS -pe 's/[^\p{Hiragana}\p{Katakana}\p{Han}]//g')
  echo ${#jp_only}
}

_ai_send_to_claude() {
  local msg="$1"
  echo ""
  echo "Claudeへ送信:"
  echo "--------------------------------"
  echo "$msg"
  echo "--------------------------------"
  echo ""
  claude --print --no-session-persistence "$msg"
}

_ai_should_send() {
  local cmd="$1"

  [[ "$cmd" == /* ]] && return 1

  # sayコマンドの引数に日本語が含まれても誤検知しないよう除外
  [[ "${cmd%% *}" == "say" ]] && return 1

  local total=${#cmd}
  (( total < AI_MIN_LEN )) && return 1

  local jp=$(_ai_jp_len "$cmd")
  (( jp == 0 )) && return 1

  perl -e "exit(($jp / $total) >= $AI_JP_RATIO_THRESHOLD ? 0 : 1)"
}

_ai_accept_line() {
  local cmd="$BUFFER"

  if _ai_should_send "$cmd"; then
    _ai_send_to_claude "$cmd"

    BUFFER=""
    zle reset-prompt

    zle .send-break
    return 0
  fi

  zle .accept-line
}

zle -N _ai_accept_line

bindkey '^M' _ai_accept_line
bindkey '^J' _ai_accept_line

# ★さらに accept-line 自体も上書き（プラグインのbindkey回避）
zle -N accept-line _ai_accept_line
