# nix
echo "✔ install nix"
mkdir /nix
chown $USER /nix
curl -L https://nixos.org/nix/install | sh
source $HOME/.nix-profile/etc/profile.d/nix.sh
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update

# home-manager
echo "✔ install home-manager"
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
cp ./home.nix ~/.config/nixpkgs/home.nix
nix-env --set-flag priority 10 nix
nix-env --set-flag priority 10 home-manager-path
nix-shell '<home-manager>' -A install

# end
# nix-collect-garbage
echo "✔ installed"
