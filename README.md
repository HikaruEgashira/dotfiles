# dotfiles

hikae's reproducible dev environment, declared as a Nix flake on top of [home-manager](https://github.com/nix-community/home-manager). Targets `aarch64-darwin`; CI evaluates the home-manager configuration and builds a minimum equipment closure on `aarch64-linux` to keep the modules portable.

## Install

```bash
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

## Daily ops

Run these from the repository so the formatter and update app target the right project:

```bash
cd ~/dotfiles
nix run .#homeConfigurations.hikae.activationPackage  # apply
nix run .#update                                     # bump inputs + eval gate; add -- --activate to apply
nix fmt                                             # format nix/yaml/md/sh/json
nix flake check                                     # evaluate outputs and build checks for the current system
brew bundle --file=./Brewfile                        # residual GUI / kext / tap
./scripts/sudo-touchid.sh status                     # inspect; use enable or disable to change
```

`nix flake update` takes input names, not a directory. To update directly from another directory, use `nix flake update --flake ~/dotfiles` (without the update app's eval gate).
See [playbooks](docs/playbooks.md) for the procedure index and [operations](docs/operations.md) for details.

A launchd agent (`modules/programs/dotfiles-sync.nix`) pulls `origin/main` and re-activates daily at 09:00 when the working tree is clean.
A weekly GitHub Actions job (`flake-update.yml`) commits and pushes `flake.lock` changes directly to `main`, then dispatches `ci.yml` and `activation-darwin.yml` (a `GITHUB_TOKEN` push starts no workflow on its own). `ci.yml` and the update job run on the self-hosted `aarch64-linux` runner `hikae-flash`; `activation-darwin` builds the real `aarch64-darwin` activation on the self-hosted runner `hikae` and reverts the bump when it breaks the build; both runners are registered per machine ([operations](docs/operations.md) §3.6).

## Layout

```
flake.nix                root: pins nixpkgs / home-manager / treefmt-nix
home.nix                 wires the modules below
modules/
  home.nix               username, ~/.npmrc, identity
  packages.nix           CLI / GUI / build deps via nixpkgs
  fonts.nix              Cica + PlemolJP NF (fontconfig)
  programs/
    artex.nix            launchd agents: ARTEX + Postgres on loopback, no inbound exposure
    aws.nix              ~/.aws/config; readonly default + step-up MFA role
    cli-tools.nix        fzf / bat / lsd / aria2 / starship
    cmux.nix             cmux settings.json + macOS defaults
    codex.nix            ~/.codex/AGENTS.md via the Claude global guidance
    dotfiles-sync.nix    launchd agent: daily git pull + home-manager switch
    ghostty.nix          terminal config + cmd+* → tmux prefix bridge
    git.nix              identity, signing, hooks (pleno-dlp pre-commit)
    github-runner.nix    launchd agent: self-hosted GHA runner for darwin activation
    tmux.nix             prefix C-a, vim panes, Tokyo Night status
    zsh.nix              shell init, aliases, secrets via age
  settings/              read-by-zsh helper scripts and cheatsheets
Brewfile                 nixpkgs に無い / broken / kext 必須なものだけ
.github/workflows/       CI (fmt + build) + weekly flake update + darwin activation repair
```

## Conventions

- `pkgs.<name>` でいけるものは `lib/package-registry.nix` に `mkEntry { pkg; purpose; reason; }` で宣言。設定が要るものは `modules/programs/<name>.nix` に分離。
- `Brewfile` は **逃げ場**。nixpkgs 化できたら追い出す。各エントリに残す理由をコメントで残す。
- 全 nix / yaml / md / sh は `nix fmt` (treefmt: nixfmt + prettier + shfmt) で揃える。CI は整形、lint、activation テスト、最小構成のビルド、home-manager の eval と determinism を検証する。
