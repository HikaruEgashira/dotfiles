#!/usr/bin/bash

# nix
echo "✔ install nix"
sh <(curl -L https://nixos.org/nix/install) --no-daemon
. $HOME/.nix-profile/etc/profile.d/nix.sh

# home-manager
echo "✔ install home-manager"
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --add https://github.com/nix-community/home-manager/archive/release-21.11.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
nix-shell '<home-manager>' -A install
. $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh

ln -f ./home.nix ~/.config/nixpkgs # cp -f ./home.nix ~/.config/nixpkgs
nix-env --set-flag priority 10 nix
home-manager switch

# end
nix-collect-garbage
echo "✔ installed"
