## usage

https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH#how-to-install-zsh-on-many-platforms

```bash
if [ ! -d /nix ]; then
    sudo mkdir /nix && sudo chown $USER /nix
fi
chmod -x *.sh
. ./install.sh
```

## enter zsh

```bash
. $HOME/.nix-profile/etc/profile.d/nix.sh
zsh
```

# (optional) install n

```
curl -L https://git.io/n-install | bash # WIP install node
```
