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
export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
nix-shell '<home-manager>' -A install

# config
cp -f .zshrc $HOME

nix-collect-garbage
echo "✔ installed"
