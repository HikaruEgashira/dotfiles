# dotfiles Brewfile
#
# Nix flake で表現できないものをここで宣言的に管理する。
# 適用: brew bundle --file=~/dotfiles/Brewfile
# クリーンアップ: brew bundle cleanup --file=~/dotfiles/Brewfile --force
#
# 大半のCLIは modules/packages.nix (Nix flake) で SLSA L3 相当に管理。
# 残った理由:
#   - nixpkgs に存在しない (cliclick, sisakulint, m1-terraform-provider-helper, ghir, block-goose, arc, sequel-ace, session-manager-plugin)
#   - nixpkgs で broken (mole)
#   - kext 必要で macOS でしか動かない (macfuse, fuse-t)
#   - darwin で nix unfree GUI が動作不安定 (slack/discord/spotify/cursor/vscode/google-chrome/raycast/obs/calibre/bitwarden/codex)
#   - cask の brew 依存で ripgrep が解放できない (codex を nix 化したら ripgrep は削除可)

# === Taps ===
tap "kreuzwerker/taps"          # m1-terraform-provider-helper
tap "macos-fuse-t/cask"         # fuse-t
tap "sisaku-security/sisakulint"
tap "suzuki-shunsuke/ghir"
tap "tw93/tap"                  # mole

# === Formulae (nixpkgs に存在しない / broken のみ) ===
brew "cliclick"
brew "openvpn", link: false     # nix 側にも openvpn あり、衝突避けで link: false
brew "ripgrep"                  # codex (cask) が依存
brew "kreuzwerker/taps/m1-terraform-provider-helper"
brew "sisaku-security/sisakulint/sisakulint"
brew "tw93/tap/mole"

# === Casks (darwin GUI / kext / nixpkgs 不在) ===
cask "arc"
cask "bitwarden"
cask "block-goose"
cask "calibre"
cask "codex"
cask "cursor"
cask "discord"
cask "macos-fuse-t/cask/fuse-t"
cask "macos-fuse-t/cask/fuse-t-sshfs"
cask "suzuki-shunsuke/ghir/ghir"
cask "google-chrome"
cask "macfuse"
cask "obs"
cask "raycast"
cask "sequel-ace"
cask "session-manager-plugin"
cask "slack"
cask "spotify"
cask "visual-studio-code"

# === Mac App Store ===
mas "Xcode", id: 497799835
