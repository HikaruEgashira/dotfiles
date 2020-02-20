# curl gitがあることを前提としてます。
# curl gitがない場合はworkflow/main.ymlを参考にインストールしてください

# nix
mkdir /nix
chown alice /nix
curl https://nixos.org/nix/install | bash -s -- --no-daemon
source $HOME/.nix-profile/etc/profile.d/nix.sh
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update
nix-env -iA nixpkgs.cachix
nix-env -iA nixpkgs.zsh nixpkgs.ghq nixpkgs.peco

# node
nix-env -iA nixpkgs.yarn
# curl -L https://git.io/n-install | bash

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
