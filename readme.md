# dotfiles

## Requirements

- [Nix](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)

## Setup

```bash
ln -f ./home.nix ~/.config/nixpkgs/home.nix
home-manager switch
```

### (WIP) install nix home-manager

```bash
if [ ! -d /nix ]; then
    sudo mkdir /nix && sudo chown $USER /nix
fi
chmod -x *.sh
. ./install.sh
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
