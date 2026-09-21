# dotfiles Brewfile
#
# Nix flake で表現できないものをここで宣言的に管理する。
# 適用: brew bundle --file=~/dotfiles/Brewfile
# クリーンアップ: brew bundle cleanup --file=~/dotfiles/Brewfile --force
#
# 大半のCLI / GUI は modules/packages.nix (Nix flake) で hash-pinned 管理。
# ここに残る理由:
#   - nixpkgs に存在しない (sisakulint, arm-none-eabi-gcc, googleworkspace-cli, icarus-verilog, higgsfield, pleno-dlp, oracle, graphite, tailscale-app, windows-app)
#   - linux-only / nix darwin 未対応 (obs)
#   - cask の brew 依存で ripgrep が解放できない (codex を nix 化したら ripgrep は削除可)
#   - codex は brew cask=GUI / nixpkgs.codex=CLI で別物

# === Taps ===
tap "higgsfield-ai/tap"         # higgsfield (nixpkgs 無し)
tap "plenoai/tap"               # pleno-dlp (nixpkgs 無し)
tap "sisaku-security/sisakulint" # sisakulint (nixpkgs 無し)
tap "steipete/tap"              # oracle (nixpkgs 無し)
tap "withgraphite/tap"          # graphite (nixpkgs 無し)

# === Formulae ===
# nixpkgs に存在しないもののみ (移行済み 11 本は lib/package-registry.nix へ)
brew "arm-none-eabi-gcc"
brew "googleworkspace-cli"
brew "higgsfield-ai/tap/higgsfield"
brew "icarus-verilog"
brew "plenoai/tap/pleno-dlp"
brew "ripgrep"                  # codex (cask) が依存
brew "sisaku-security/sisakulint/sisakulint"
brew "steipete/tap/oracle"
brew "withgraphite/tap/graphite"

# === Casks (darwin 限定 / nixpkgs 不在) ===
cask "codex"                    # GUI: nix の codex は CLI で別物
cask "ghostty"
cask "obs"                      # nix obs-studio は linux-only
cask "tailscale-app"            # nixpkgs 無し (GUI)
cask "windows-app"              # nixpkgs 無し (GUI)

# === Mac App Store ===
mas "Xcode", id: 497799835
