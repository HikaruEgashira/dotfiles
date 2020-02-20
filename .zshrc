autoload -Uz compinit
compinit
source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
source "${ZDOTDIR:-$HOME}/.nix-profile/etc/profile.d/nix.sh"

function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

function _cd()
{
  \cd $@ && ls
}
alias cd='_cd'

function _rm()
{
  \rm $@ && ls
}
alias rm='_rm'

# export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
# export NODE_OPTIONS=--max_old_space_size=8192
