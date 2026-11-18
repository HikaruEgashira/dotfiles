# dotfiles

hikae's reproducible dev environment, declared as a Nix flake on top of [nix-darwin](https://github.com/nix-darwin/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager). The OS layer (`/etc`, `defaults`, sudo/PAM, firewall, signed system installers) is `darwinConfigurations.hikae` from `hosts/macbook-air` and needs root; the user layer (packages, Aqua, dotfiles, launchd agents) is `homeConfigurations.hikae` from `home.nix` and activates as the user. CI evaluates the home-manager configuration and builds a minimum equipment closure on `aarch64-linux` to keep the modules portable.

## Install

```bash
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run nix-darwin/master -- switch --flake ~/dotfiles#hikae   # OS layer (sudo)
nix run ~/dotfiles#switch                                       # user layer, no root
```

## Daily ops

Run these from the repository so the formatter and update app target the right project:

```bash
cd ~/dotfiles
nix run .#switch                                     # user layer as $USER; darwin-rebuild via sudo only when the OS layer changed
nix run .#update                                     # bump inputs + substitutable gate; add -- --activate to apply
nix run .#substitutable-gate                         # assert nothing in the darwin/home closure needs a local source build
nix fmt                                             # format nix/yaml/md/sh/json
nix flake check                                     # evaluate outputs and build checks for the current system
```

`nix flake update` takes input names, not a directory. To update directly from another directory, use `nix flake update --flake ~/dotfiles` (without the update app's eval gate).
See [playbooks](docs/playbooks.md) for the procedure index and [operations](docs/operations.md) for details.

A launchd agent (`modules/programs/dotfiles-sync.nix`) pulls `origin/main` daily at 09:00 when the working tree is clean, activates the user layer, and builds the darwin system. The OS layer needs root, so it records `pending=yes` in `~/.cache/dotfiles-sync/metrics.jsonl` instead of switching it; apply with `nix run .#switch`.
A weekly GitHub Actions job (`flake-update.yml`) runs the substitutable gate on the bumped lock, commits and pushes `flake.lock` changes directly to `main`, then dispatches `ci.yml` (a `GITHUB_TOKEN` push starts no workflow on its own). The real `aarch64-darwin` build is verified locally by `dotfiles-sync` and `nix run .#switch`.

### gypxy hub on ms-a2

The hub (`modules/programs/gypxy.nix`) runs a store copy of the gypxy release pinned by `modules/programs/aqua/aqua.yaml` and hashed by `aqua-checksums.json`; it never fetches at start. The release is private, so neither nix nor the non-interactive service can download it. To bump the version:

```bash
# 1. on the Mac: bump the pin, refresh checksums, open a PR (tests/gypxy-hub.sh checks pin and hash agree)
sed -i '' 's|gh-intel@gypxy/v.*|gh-intel@gypxy/vX.Y.Z|' modules/programs/aqua/aqua.yaml
aqua update-checksum -a --prune
# 2. on the Mac: verify the cosign bundle and sha256, then add the asset to the ms-a2 store
scripts/gypxy-seed.sh ms-a2
# 3. after merge, on ms-a2: build and activate the user layer (no sudo)
hm=$(nix build --no-link --print-out-paths --refresh \
  "github:HikaruEgashira/dotfiles/main#nixosConfigurations.ms-a2.config.home-manager.users.hikae.home.activationPackage")
"$hm/activate"
```

If step 2 was skipped, the build in step 3 fails and the running hub keeps serving the previous version. Activation restarts the unit only when the store path changes; the restart closes the listener until the new process binds, so the gap is the shutdown of in-flight requests plus start-up.

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
    native-apps.nix      signed pkg / Mac App Store bootstrap
  home.nix               username, ~/.npmrc, identity
  packages.nix           CLI / GUI / build deps via nixpkgs
  fonts.nix              Cica + PlemolJP NF (fontconfig)
  programs/
    artex.nix            launchd agents: ARTEX on loopback, Postgres on a private unix socket with scram auth
    aqua.nix             checksum 必須の prebuilt CLI registry
    aws.nix              ~/.aws/config; readonly default + step-up MFA role
    cli-tools.nix        fzf / bat / lsd / aria2 / starship
    cmux.nix             cmux settings.json + macOS defaults
    codex.nix            ~/.codex/AGENTS.md via the Claude global guidance
    dotfiles-sync.nix    launchd agent: daily git pull, user-layer activation, OS-layer build
    ghostty.nix          terminal config + cmd+* → tmux prefix bridge
    git.nix              identity, signing, hooks (pleno-dlp pre-commit)
    tmux.nix             prefix C-a, vim panes, Tokyo Night status
    zsh.nix              shell init, aliases, secrets via age
.github/workflows/       CI (fmt + eval + lint) + weekly flake update
```

## Conventions

- `pkgs.<name>` でいけるものは `lib/package-registry.nix` に `mkEntry { pkg; purpose; reason; }` で宣言。設定が要るものは `modules/programs/<name>.nix` に分離。
- cache に無い prebuilt CLI は `modules/programs/aqua/`、GUI は署名を検証する native installer に置き、source build はしない。
- 全 nix / yaml / md / sh は `nix fmt` (treefmt: nixfmt + prettier + shfmt) で揃える。CI は整形、lint、home-manager の eval と determinism、最小構成のビルドを検証する。
