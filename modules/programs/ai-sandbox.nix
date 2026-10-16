# claude / codex の sandbox 許可を 1 箇所で定義し、各 CLI の設定レイヤに配る。
# 方針は「sandbox は有効のまま、開発で弾かれない範囲まで許可を広げる」。
# 書き込みは $HOME 配下 (uv/npm/mise 等のキャッシュ・ghq の repo を含む) と
# ユーザが書ける OS 領域、通信は全ドメインを許す。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;

  writable = [
    home
    "/tmp"
    "/private/tmp"
    "/private/var/folders"
    "/opt/homebrew"
    "/usr/local"
  ];

  claudeSettings = {
    sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = true;
      allowUnsandboxedCommands = true;
      network = {
        allowedDomains = [ "*" ];
        allowAllUnixSockets = true;
        allowLocalBinding = true;
        allowMachLookup = [ "*" ];
      };
      filesystem.allowWrite = writable;
      allowAppleEvents = true;
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
    exec "$real" --settings ${lib.escapeShellArg "${config.xdg.configHome}/claude/sandbox.json"} "$@"
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
