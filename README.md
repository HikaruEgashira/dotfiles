# dotfiles

hikae's reproducible dev environment, declared as a Nix flake on top of [nix-darwin](https://github.com/nix-darwin/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager). The machine layer (`/etc`, `defaults`, sudo/PAM, firewall, launchd, Homebrew) is declared in `hosts/macbook-air`; the user layer lives in `modules/`. CI evaluates the home-manager configuration and builds a minimum equipment closure on `aarch64-linux` to keep the modules portable.

## Install

```bash
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run nix-darwin/master -- switch --flake ~/dotfiles#hikae
```

## Daily ops

Run these from the repository so the formatter and update app target the right project:

```bash
cd ~/dotfiles
nix run .#switch                                     # user layer as $USER; darwin-rebuild via sudo only when the OS layer changed
nix run .#update                                     # bump inputs + eval gate; add -- --activate to apply
nix fmt                                             # format nix/yaml/md/sh/json
nix flake check                                     # evaluate outputs and build checks for the current system
```

`nix flake update` takes input names, not a directory. To update directly from another directory, use `nix flake update --flake ~/dotfiles` (without the update app's eval gate).
See [playbooks](docs/playbooks.md) for the procedure index and [operations](docs/operations.md) for details.

A launchd agent (`modules/programs/dotfiles-sync.nix`) pulls `origin/main` daily at 09:00 when the working tree is clean, activates the user layer, and builds the darwin system. The OS layer needs root, so it records `pending=yes` in `~/.cache/dotfiles-sync/metrics.jsonl` instead of switching it; apply with `nix run .#switch`.
A weekly GitHub Actions job (`flake-update.yml`) commits and pushes `flake.lock` changes directly to `main`, then dispatches `ci.yml` (a `GITHUB_TOKEN` push starts no workflow on its own). No self-hosted runner is registered on a personal machine: the real `aarch64-darwin` build is verified locally by `dotfiles-sync` and `nix run .#switch`.

## Layout

```
flake.nix                root: pins nixpkgs / nix-darwin / home-manager / treefmt-nix
home.nix                 wires the user modules
hosts/macbook-air/       darwin system: imports modules/darwin/*
modules/
  darwin/
    nix.nix              nix.conf (daemon settings, substituters, trusted users)
    security.nix         application firewall + verification, Touch ID sudo, Wi-Fi DNS
    system.nix           stateVersion, primary user, SoftwareUpdate defaults
    homebrew.nix         nixpkgs に無い formulae / casks / mas (逃げ場)
  home.nix               username, ~/.npmrc, identity
  packages.nix           CLI / GUI / build deps via nixpkgs
  fonts.nix              Cica + PlemolJP NF (fontconfig)
  programs/
    artex.nix            launchd agents: ARTEX + Postgres on loopback, no inbound exposure
    aws.nix              ~/.aws/config; readonly default + step-up MFA role
    cli-tools.nix        fzf / bat / lsd / aria2 / starship
    cmux.nix             cmux settings.json + macOS defaults
    codex.nix            ~/.codex/AGENTS.md via the Claude global guidance
    dotfiles-sync.nix    launchd agent: daily git pull + system build
    ghostty.nix          terminal config + cmd+* → tmux prefix bridge
    git.nix              identity, signing, hooks (pleno-dlp pre-commit)
    tmux.nix             prefix C-a, vim panes, Tokyo Night status
    zsh.nix              shell init, aliases, secrets via age
  settings/              read-by-zsh helper scripts and cheatsheets
.github/workflows/       CI (fmt + build) + weekly flake update + darwin activation repair
```

## Conventions

- `pkgs.<name>` でいけるものは `lib/package-registry.nix` に `mkEntry { pkg; purpose; reason; }` で宣言。設定が要るものは `modules/programs/<name>.nix` に分離。
- `modules/darwin/homebrew.nix` は **逃げ場**。nixpkgs 化できたら追い出す。各エントリに残す理由をコメントで残す。
- 全 nix / yaml / md / sh は `nix fmt` (treefmt: nixfmt + prettier + shfmt) で揃える。CI は整形、lint、activation テスト、最小構成のビルド、home-manager の eval と determinism を検証する。
