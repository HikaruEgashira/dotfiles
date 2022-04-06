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

mkdir -p $HOME/.config/nixpkgs
ln -s ./home.nix $HOME/.config/nixpkgs/home.nix
# nix-env --set-flag priority 10 nix
nix-shell -I $HOME/.nix-defexpr/channels '<home-manager>' -A install # home-manager switch

# end
nix-collect-garbage
echo "✔ installed"
