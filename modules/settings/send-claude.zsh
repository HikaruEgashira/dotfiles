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
  local cmd="$1" word
  [[ "$cmd" == /* ]] && return 1
  word=${cmd%% *}
  [[ "$word" == *=* ]] && return 1
  (( $+commands[$word] )) && return 1
  [[ "$cmd" == *[ぁ-ゖ]* || "$cmd" == *[ァ-ヺ]* || "$cmd" == *[一-龯]* ]]
}

_ai_accept_line() {
  if _ai_should_send "$BUFFER"; then
    _ai_send_to_claude "$BUFFER"

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

# override accept-line so plugin bindkeys can't bypass us
zle -N accept-line _ai_accept_line
