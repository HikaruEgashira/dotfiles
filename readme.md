### dotfiles

Prerequisites
- [Nix](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)

Installation
```bash
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run home-manager -- -f ~/dotfiles/home.nix switch
```
