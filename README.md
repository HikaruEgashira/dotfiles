# dotfiles

hikae's reproducible dev environment, declared as a Nix flake on top of [home-manager](https://github.com/nix-community/home-manager). Targets `aarch64-darwin`; CI builds the same closure on `x86_64-linux` to keep the modules portable.

## Install

```bash
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

## Daily ops

```bash
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage   # apply
nix flake update ~/dotfiles                                     # bump inputs
nix fmt ~/dotfiles                                              # format nix/yaml/md/sh
nix flake check ~/dotfiles                                      # build + fmt gate
brew bundle --file=~/dotfiles/Brewfile                          # residual GUI / kext / tap
~/dotfiles/scripts/sudo-touchid.sh status|enable|disable        # manage Touch ID for sudo safely
```

A launchd agent (`modules/programs/dotfiles-sync.nix`) pulls `origin/main` and re-activates daily at 09:00 when the working tree is clean.
A weekly GitHub Actions job (`flake-update.yml`) opens an auto-merge PR with the latest `flake.lock`.

## Layout

```
flake.nix                root: pins nixpkgs / home-manager / treefmt-nix
home.nix                 wires the modules below
modules/
  home.nix               username, ~/.npmrc, identity
  packages.nix           CLI / GUI / build deps via nixpkgs
  fonts.nix              Cica + PlemolJP NF (fontconfig)
  programs/
    aws.nix              ~/.aws/config; readonly default + step-up MFA role
    cli-tools.nix        fzf / bat / lsd / aria2 / starship
    cmux.nix             cmux settings.json + macOS defaults
    codex.nix            ~/.codex/AGENTS.md via the Claude global guidance
    dotfiles-sync.nix    launchd agent: daily git pull + home-manager switch
    ghostty.nix          terminal config + cmd+* → tmux prefix bridge
    git.nix              identity, signing, hooks (gitleaks pre-commit)
    tmux.nix             prefix C-a, vim panes, Tokyo Night status
    zsh.nix              shell init, aliases, secrets via dotenvx
  settings/              read-by-zsh helper scripts and cheatsheets
Brewfile                 nixpkgs に無い / broken / kext 必須なものだけ
.github/workflows/       CI (fmt + build) + weekly flake update
```

## Conventions

- `pkgs.<name>` でいけるものは `modules/packages.nix`、設定が要るものは `modules/programs/<name>.nix` に分離。
- `Brewfile` は **逃げ場**。nixpkgs 化できたら追い出す。各エントリに残す理由をコメントで残す。
- 全 nix / yaml / md / sh は `nix fmt` (treefmt: nixfmt + prettier + shfmt) で揃える。CI で `nix flake check` がフォーマットとビルド両方をゲートする。
