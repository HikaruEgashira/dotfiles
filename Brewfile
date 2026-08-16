# dotfiles Brewfile
#
# Nix flake で表現できないものをここで宣言的に管理する。
# 適用: brew bundle --file=~/dotfiles/Brewfile
# クリーンアップ: brew bundle cleanup --file=~/dotfiles/Brewfile --force
#
# 大半のCLI / GUI は modules/packages.nix (Nix flake) で hash-pinned 管理。
# 残った理由:
#   - nixpkgs に存在しない (cliclick, sisakulint, m1-terraform-provider-helper, ghir, block-goose, arc, sequel-ace, session-manager-plugin)
#   - nixpkgs で broken (calibre)
#   - kext 必要で macOS でしか動かない (macfuse, fuse-t, fuse-t-sshfs)
#   - linux-only / nix darwin 未対応 (obs)
#   - cask の brew 依存で ripgrep が解放できない (codex を nix 化したら ripgrep は削除可)
#   - codex は brew cask=GUI / nixpkgs.codex=CLI で別物

# === Taps ===
tap "kreuzwerker/taps"          # m1-terraform-provider-helper
tap "macos-fuse-t/cask"         # fuse-t
tap "sisaku-security/sisakulint"
tap "suzuki-shunsuke/ghir"

# === Formulae (nixpkgs に存在しない / broken のみ) ===
brew "checkov"                  # nixpkgs ≥ 2026-04-27 の python313-av で aarch64-darwin import check が SIGKILL
brew "cliclick"
brew "ripgrep"                  # codex (cask) が依存
brew "kreuzwerker/taps/m1-terraform-provider-helper"
brew "sisaku-security/sisakulint/sisakulint"

# === Casks (darwin 限定 / kext / nixpkgs 不在) ===
cask "arc"
cask "block-goose"
cask "calibre"                  # nixpkgs broken
cask "codex"                    # GUI: nix の codex は CLI で別物
cask "ghostty"
cask "macos-fuse-t/cask/fuse-t"
cask "macos-fuse-t/cask/fuse-t-sshfs"
cask "suzuki-shunsuke/ghir/ghir"
cask "macfuse"
cask "obs"                      # nix obs-studio は linux-only
cask "sequel-ace"
cask "session-manager-plugin"

# === Mac App Store ===
mas "Xcode", id: 497799835

# === VS Code Extensions ===
# modules/programs/vscode.nix に移行済み (nix-vscode-extensions overlay 経由)。
# このセクションに `vscode "..."` 行を追加すると CI Brewfile lint で fail する。
