# app config
autoload -Uz compinit
compinit
source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
source "${ZDOTDIR:-$HOME}/.nix-profile/etc/profile.d/nix.sh"
source "${ZDOTDIR:-$HOME}/.fzf.zsh"
eval "$(direnv hook zsh)"

# function
function fzf-src () {
  local selected_dir=$(ghq list -p | fzf --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N fzf-src
bindkey '^]' fzf-src

function _cd()
{
  \cd $@ && ls
}

function _rm()
{
  \rm $@ && ls
}

# alias
alias cd='_cd'
alias rm='_rm'
alias c="code ."
alias cr="c -r"
alias zshrc="source ~/.zshrc"
alias fd=fdfind

# path
export N_PREFIX="$HOME/n"
export PATH="$N_PREFIX/bin:$PATH"
