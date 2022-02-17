#!/usr/bin/bash

# nix
echo "✔ install nix"
if [ ! -d /nix ]; then sudo mkdir /nix && sudo chown $USER /nix
fi
curl -L https://nixos.org/nix/install | sh
source $HOME/.nix-profile/etc/profile.d/nix.sh
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update

# home-manager
echo "✔ install home-manager"
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-env --set-flag priority 10 nix
nix-env --set-flag priority 10 home-manager-path
nix-shell '<home-manager>' -A install

# sync
ln -f ./home.nix ~/.config/nixpkgs
home-manager switch

# end
nix-collect-garbage
echo "✔ installed"
