# app config
source "$HOME/.nix-profile/etc/profile.d/nix.sh"

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
bindkey '^g' fzf-src

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
alias ls='lsd'
alias c="code ."
alias rel="source ~/.zshrc"
alias fd=fdfind

# path
export N_PREFIX="$HOME/n"
export PATH="$N_PREFIX/bin:$PATH"
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
