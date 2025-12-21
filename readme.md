# dotfiles

## Requirements

- [Nix](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)

## Setup

```bash
# clone
gh repo clone HikaruEgashira/dotfiles
cd dotfiles

# setup config
mkdir -p $HOME/.config/home-manager
ln -f ./home.nix $HOME/.config/home-manager/home.nix

# edit ./home.nix
sed -i "s|hikae|$USER|g" ./home.nix  # etc...

# setup home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
nix-shell -I $HOME/.nix-defexpr/channels '<home-manager>' -A install # home-manager switch
```

https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

### install nix

```bash
if [ ! -d /nix ]; then
    sudo mkdir /nix && sudo chown $USER /nix
fi
sh <(curl -L https://nixos.org/nix/install) --no-daemon
. $HOME/.nix-profile/etc/profile.d/nix.sh
```

https://nixos.org/download/

### uninstall

NOTICE: remove `. "\$HOME/.nix-profile/etc/profile.d/nix.sh"` line in your `~/.zshrc`

```bash
rm -rf $HOME/{.nix-channels,.nix-defexpr,.nix-profile,.config/home-manager}
sudo rm -rf /nix
```

# font list

- Mono: [Cica](https://github.com/miiton/Cica)
- English: [Lato](https://fonts.google.com/specimen/Lato)
- JP: [Zen Kaku Gothic New](https://fonts.google.com/specimen/Zen+Kaku+Gothic+New)

# トラブルシュート

- nixが見つからなくなった
```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

- home-managerが失敗する
```sh
nix-channel --remove home-manager && nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && nix-channel --update
```

# Docker

https://zenn.dev/sqer/articles/644bb456c56c0f
https://docs.docker.com/compose/install/linux/#install-the-plugin-manually

# install nerdctl

https://github.com/containerd/nerdctl/releases

```sh
curl -sSL https://github.com/containerd/nerdctl/releases/download/v1.7.2/nerdctl-full-1.7.2-linux-amd64.tar.gz | sudo tar Cxzv /usr/local/
sudo systemctl enable --now containerd
sudo nerdctl run -d --name nginx -p 80:80 nginx:alpine
```
