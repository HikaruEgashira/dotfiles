# claude / codex の sandbox 許可を 1 箇所で定義し、各 CLI の設定レイヤに配る。
# 方針は「読みは全許可・書きは $HOME とユーザ書き込み可能領域・シークレットだけ deny」。
# live の settings.json / config.toml は触らず、wrapper が --settings / -c で重ねる。
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

  secrets = [
    "${home}/.ssh"
    "${home}/.aws"
    "${home}/.gnupg"
    "${home}/.netrc"
    "${home}/.git-credentials"
    "${home}/.kube"
    "${home}/.password-store"
    "${home}/.docker/config.json"
    "${home}/.codex/auth.json"
    "${home}/.claude/.credentials.json"
    "${home}/.config/gcloud"
    "${home}/.config/opencodex"
    "${home}/.config/secrets"
  ];

  # sandbox 内の git commit が署名・検証できるよう、署名に要るファイルだけ read を戻す
  signingRead =
    let
      git = config.programs.git;
      allowedSigners = git.settings.gpg.ssh.allowedSignersFile or null;
    in
    lib.optionals (git.signing.key != null) (
      [ git.signing.key ] ++ lib.optional (allowedSigners != null) allowedSigners
    );

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
      filesystem = {
        allowWrite = writable;
        allowRead = signingRead;
        denyRead = secrets;
        denyWrite = secrets;
      };
      allowAppleEvents = true;
    };
  };

  # codex permission profile: "/" 読取、writable 書込、secrets deny (deny は同特異度に勝つ)
  codexFilesystem = {
    "/" = "read";
  }
  // lib.genAttrs writable (_: "write")
  // lib.genAttrs secrets (_: "deny")
  // lib.genAttrs signingRead (_: "read");
  filesystemToml = "{${
    lib.concatMapStringsSep "," (p: ''"${p}"="${codexFilesystem.${p}}"'') (
      builtins.attrNames codexFilesystem
    )
  }}";

  codexArgs = [
    ''default_permissions="dev"''
    "permissions.dev.filesystem=${filesystemToml}"
    "permissions.dev.network={enabled=true}"
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
