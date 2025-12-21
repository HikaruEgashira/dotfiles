# dotfiles

## Requirements

- [Nix](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)

## Setup

```bash
# clone
gh repo clone HikaruEgashira/dotfiles
nix run home-manager -- -f ~/dotfiles/home.nix switch
```

https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

# font

- Mono: [Cica](https://github.com/miiton/Cica)
- English: [Lato](https://fonts.google.com/specimen/Lato)
- JP: [Zen Kaku Gothic New](https://fonts.google.com/specimen/Zen+Kaku+Gothic+New)

# Docker

https://zenn.dev/sqer/articles/644bb456c56c0f
https://docs.docker.com/compose/install/linux/#install-the-plugin-manually

nerdctl
```sh
curl -sSL https://github.com/containerd/nerdctl/releases/download/v1.7.2/nerdctl-full-1.7.2-linux-amd64.tar.gz | sudo tar Cxzv /usr/local/
sudo systemctl enable --now containerd
sudo nerdctl run -d --name nginx -p 80:80 nginx:alpine
```
