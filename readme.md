# dotfiles

## Requirements

- [Nix](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)

## Setup

```bash
mkdir -p $HOME/.config/nixpkgs
ln -s ./home.nix $HOME/.config/nixpkgs/home.nix

nix-channel --add https://github.com/nix-community/home-manager/archive/release-21.11.tar.gz home-manager
nix-channel --update
nix-shell -I $HOME/.nix-defexpr/channels '<home-manager>' -A install # home-manager switch
```

### install nix

```bash
if [ ! -d /nix ]; then
    sudo mkdir /nix && sudo chown $USER /nix
fi
sh <(curl -L https://nixos.org/nix/install) --no-daemon
. $HOME/.nix-profile/etc/profile.d/nix.sh
```

### uninstall

NOTICE: remove `. "\$HOME/.nix-profile/etc/profile.d/nix.sh"` line in your `~/.zshrc`

```bash
rm -rf $HOME/{.nix-channels,.nix-defexpr,.nix-profile,.config/nixpkgs}
sudo rm -rf /nix
```

# (optional) install n

```
curl -L https://git.io/n-install | bash
```

# font list

WSLメインなのでHome-managerで管理しない

- English: [Lato](https://fonts.google.com/specimen/Lato) # エディタには入れない
- Code: [MesloLGS NF](https://github.com/romkatv/powerlevel10k#fonts)
- JP: [Zen Kaku Gothic New](https://fonts.google.com/specimen/Zen+Kaku+Gothic+New)
