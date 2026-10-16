# claude / codex の sandbox 許可を 1 箇所で定義し、各 CLI の設定レイヤに配る。
# 書き込み可は nix が決めた XDG ルートとワークスペースのみ、通信は取得系ドメインのみ。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  inherit (config.xdg) cacheHome configHome dataHome;

  writable = [
    "${cacheHome}/uv"
    "${dataHome}/uv"
    "${cacheHome}/npm"
    "${cacheHome}/pnpm"
    "${cacheHome}/pip"
    "${cacheHome}/mise"
    "${dataHome}/mise"
    "${dataHome}/go"
    "${dataHome}/bun"
    "${dataHome}/rustup"
    "${cacheHome}/sccache"
    "${cacheHome}/terraform"
    # XDG 非対応ツールの macOS 既定キャッシュ
    "${home}/Library/pnpm"
    "${home}/Library/Caches/go-build"
    "${home}/Library/Caches/pip"
    "${home}/.cargo"
    "${home}/.cargo-target"
    "${home}/go"
    "${home}/ghq"
    "${home}/dotfiles"
  ];

  allowedDomains = [
    "npm.flatt.tech"
    "npm.pkg.github.com"
    "registry.npmjs.org"
    "pypi.flatt.tech"
    "pypi.org"
    "files.pythonhosted.org"
    "crates.io"
    "static.crates.io"
    "index.crates.io"
    "proxy.golang.org"
    "sum.golang.org"
    "registry.terraform.io"
    "releases.hashicorp.com"
    "github.com"
    "api.github.com"
    "codeload.github.com"
    "objects.githubusercontent.com"
    "raw.githubusercontent.com"
    "ghcr.io"
    "*.amazonaws.com"
    "*.googleapis.com"
    "api.anthropic.com"
    "claude.ai"
  ];

  claudeSettings = {
    sandbox = {
      enabled = true;
      network = {
        inherit allowedDomains;
        allowLocalBinding = true;
      };
      filesystem.allowWrite = writable;
    };
  };

  codexArgs = [
    ''sandbox_mode="workspace-write"''
    "sandbox_workspace_write.network_access=true"
    "sandbox_workspace_write.writable_roots=${builtins.toJSON writable}"
  ];

  claudeWrapper = pkgs.writeShellScript "claude-sandbox" ''
    set -eu
    real=${lib.escapeShellArg "${home}/.local/bin/claude"}
    [ -x "$real" ] || { echo "ai-sandbox: $real not found" >&2; exit 127; }
    exec "$real" --settings ${lib.escapeShellArg "${configHome}/claude/sandbox.json"} "$@"
  '';

  codexWrapper = pkgs.writeShellScript "codex-sandbox" ''
    set -eu
    real=${lib.escapeShellArg "${home}/.local/bin/codex"}
    [ -x "$real" ] || { echo "ai-sandbox: $real not found" >&2; exit 127; }
    exec "$real" ${lib.concatMapStringsSep " " (a: "-c ${lib.escapeShellArg a}") codexArgs} "$@"
  '';
in
{
  # claude/codex は自己更新する binary なので PATH を乗っ取らず、専用 dir を先頭に足す。
  # zsh の path は順序が意味を持つため、重複除去で先頭固定する。
  programs.zsh.initContent = lib.mkAfter ''
    typeset -U path PATH
    path=("$HOME/.config/ai-sandbox/bin" $path)
  '';

  home.file = {
    ".config/claude/sandbox.json".text = builtins.toJSON claudeSettings;
    ".config/ai-sandbox/bin/claude".source = claudeWrapper;
    ".config/ai-sandbox/bin/codex".source = codexWrapper;
  };
}
