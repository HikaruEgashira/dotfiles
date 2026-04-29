# dotfiles Brewfile
#
# Nix flake で表現できないものをここで宣言的に管理する。
# 適用: brew bundle --file=~/dotfiles/Brewfile
# クリーンアップ: brew bundle cleanup --file=~/dotfiles/Brewfile --force
#
# 大半のCLI / GUI は modules/packages.nix (Nix flake) で hash-pinned 管理。
# 残った理由:
#   - nixpkgs に存在しない (cliclick, sisakulint, m1-terraform-provider-helper, ghir, block-goose, arc, sequel-ace, session-manager-plugin)
#   - nixpkgs で broken (mole, calibre)
#   - kext 必要で macOS でしか動かない (macfuse, fuse-t, fuse-t-sshfs)
#   - linux-only / nix darwin 未対応 (obs)
#   - cask の brew 依存で ripgrep が解放できない (codex を nix 化したら ripgrep は削除可)
#   - codex は brew cask=GUI / nixpkgs.codex=CLI で別物

# === Taps ===
tap "kreuzwerker/taps"          # m1-terraform-provider-helper
tap "macos-fuse-t/cask"         # fuse-t
tap "sisaku-security/sisakulint"
tap "suzuki-shunsuke/ghir"
tap "tw93/tap"                  # mole

# === Formulae (nixpkgs に存在しない / broken のみ) ===
brew "checkov"                  # nixpkgs ≥ 2026-04-27 の python313-av で aarch64-darwin import check が SIGKILL
brew "cliclick"
brew "ripgrep"                  # codex (cask) が依存
brew "kreuzwerker/taps/m1-terraform-provider-helper"
brew "sisaku-security/sisakulint/sisakulint"
brew "tw93/tap/mole"

# === Casks (darwin 限定 / kext / nixpkgs 不在) ===
cask "arc"
cask "block-goose"
cask "calibre"                  # nixpkgs broken
cask "codex"                    # GUI: nix の codex は CLI で別物
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
# 将来的に programs.vscode.extensions (home-manager) に移行候補
vscode "anthropic.claude-code"
vscode "arcticicestudio.nord-visual-studio-code"
vscode "astral-sh.ty"
vscode "bierner.markdown-mermaid"
vscode "biomejs.biome"
vscode "denoland.vscode-deno"
vscode "docker.docker"
vscode "editorconfig.editorconfig"
vscode "github.copilot-chat"
vscode "github.vscode-pull-request-github"
vscode "kilocode.kilo-code"
vscode "mads-hartmann.bash-ide-vscode"
vscode "mikestead.dotenv"
vscode "ms-azuretools.vscode-containers"
vscode "ms-azuretools.vscode-docker"
vscode "ms-ceintl.vscode-language-pack-ja"
vscode "ms-python.debugpy"
vscode "ms-python.python"
vscode "ms-python.vscode-pylance"
vscode "ms-python.vscode-python-envs"
vscode "ms-vscode-remote.remote-containers"
vscode "ms-vscode-remote.remote-ssh"
vscode "ms-vscode-remote.remote-ssh-edit"
vscode "ms-vscode-remote.vscode-remote-extensionpack"
vscode "ms-vscode.anycode"
vscode "ms-vscode.anycode-c-sharp"
vscode "ms-vscode.anycode-cpp"
vscode "ms-vscode.anycode-go"
vscode "ms-vscode.anycode-java"
vscode "ms-vscode.anycode-kotlin"
vscode "ms-vscode.anycode-php"
vscode "ms-vscode.anycode-python"
vscode "ms-vscode.anycode-rust"
vscode "ms-vscode.anycode-typescript"
vscode "ms-vscode.cpptools"
vscode "ms-vscode.remote-explorer"
vscode "ms-vscode.vscode-speech"
vscode "rust-lang.rust-analyzer"
vscode "thenuprojectcontributors.vscode-nushell-lang"
vscode "vitest.explorer"
vscode "yoavbls.pretty-ts-errors"
