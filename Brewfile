# dotfiles Brewfile
#
# Nix flake で表現できないものをここで宣言的に管理する。
# 適用: brew bundle --file=~/dotfiles/Brewfile
# クリーンアップ: brew bundle cleanup --file=~/dotfiles/Brewfile --force
#
# 大半のCLI / GUI は modules/packages.nix (Nix flake) で hash-pinned 管理。
# ここに残る理由:
#   - nixpkgs に存在しない (sisakulint, higgsfield, pleno-dlp, oracle, graphite, tailscale-app, windows-app)
#   - linux-only / nix darwin 未対応 (obs)
#   - cask の brew 依存で ripgrep が解放できない (codex を nix 化したら ripgrep は削除可)
#   - codex は brew cask=GUI / nixpkgs.codex=CLI で別物
#   - 野良追従: brew に既 install だったものを管理下へ取り込んだ (nixpkgs 移行候補)

# === Taps ===
tap "higgsfield-ai/tap"         # higgsfield (nixpkgs 無し)
tap "plenoai/tap"               # pleno-dlp (nixpkgs 無し)
tap "sisaku-security/sisakulint" # sisakulint (nixpkgs 無し)
tap "steipete/tap"              # oracle (nixpkgs 無し)
tap "withgraphite/tap"          # graphite (nixpkgs 無し)

# === Formulae ===
# 野良追従: brew に既 install だったものを管理下へ (全て nixpkgs 移行候補)
brew "actionlint"
brew "arm-none-eabi-gcc"
brew "cargo-nextest"
brew "cmake"
brew "git-lfs"
brew "googleworkspace-cli"
brew "graphviz"
brew "higgsfield-ai/tap/higgsfield"
brew "hyperfine"
brew "icarus-verilog"
brew "openvpn"
brew "plenoai/tap/pleno-dlp"
brew "pnpm"
brew "poppler"
brew "powershell"
brew "ripgrep"                  # codex (cask) が依存
brew "silicon"
brew "sisaku-security/sisakulint/sisakulint"
brew "steipete/tap/oracle"
brew "tesseract"
brew "withgraphite/tap/graphite"
brew "zig@0.15"

# === Casks (darwin 限定 / nixpkgs 不在) ===
cask "codex"                    # GUI: nix の codex は CLI で別物
cask "ghostty"
cask "obs"                      # nix obs-studio は linux-only
cask "tailscale-app"            # nixpkgs 無し (GUI)
cask "windows-app"              # nixpkgs 無し (GUI)

# === Mac App Store ===
mas "Xcode", id: 497799835

# === VS Code Extensions ===
# modules/programs/vscode.nix に移行済み (nix-vscode-extensions overlay 経由)。
# このセクションに `vscode "..."` 行を追加すると CI Brewfile lint で fail する。