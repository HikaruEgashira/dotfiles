curl https://nixos.org/nix/install | sh
. .nix-profile/etc/profile.d/nix.sh
echo . .nix-profile/etc/profile.d/nix.sh >> ~/.zshrc

nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update
nix-env -iA nixpkgs.cachix

nix-env --install ghq peco fzf
