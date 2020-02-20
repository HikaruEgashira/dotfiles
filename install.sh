# curl gitがあることを前提としてます。
# curl gitがない場合はworkflow/main.ymlを参考にインストールしてください

# nix
# curl https://nixos.org/nix/install | sh
sh <(curl https://nixos.org/nix/install) --daemon
source $HOME/.nix-profile/etc/profile.d/nix.sh
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update
nix-env -iA nixpkgs.cachix
nix-env -iA nixpkgs.zsh nixpkgs.ghq nixpkgs.peco

# node
nix-env -iAnixpkgs.yarn
curl -L https://git.io/n-install | bash

# prezto
# zsh
# git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
# setopt EXTENDED_GLOB
# for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
#   ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
# done
# source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
# chsh -s /bin/zsh

nix-collect-garbage
\cp -f .zshrc $HOME
