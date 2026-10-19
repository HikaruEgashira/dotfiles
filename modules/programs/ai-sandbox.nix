# claude / codex の sandbox 許可と claude の auto mode 規則を 1 箇所で定義し、各 CLI の設定レイヤに配る。
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

  # 署名鍵は agent が保持するので sandbox に鍵ファイルを見せる必要はない
  sshAuthSock = config.home.sessionVariables.SSH_AUTH_SOCK;

  # sandbox からの永続化経路 (ログイン時に自動実行される plist) を塞ぐ
  persistence = [
    "${home}/Library/LaunchAgents"
    "/Library/LaunchAgents"
    "/Library/LaunchDaemons"
  ];

  claudeSettings = {
    autoMode = builtins.fromJSON (builtins.readFile ./claude/auto-mode.json);
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
        denyRead = secrets;
        denyWrite = secrets ++ persistence;
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
  // lib.genAttrs persistence (_: "deny");
  filesystemToml = "{${
    lib.concatMapStringsSep "," (p: ''"${p}"="${codexFilesystem.${p}}"'') (
      builtins.attrNames codexFilesystem
    )
  }}";

  codexArgs = [
    ''default_permissions="dev"''
    "permissions.dev.filesystem=${filesystemToml}"
    "permissions.dev.network={enabled=true}"
    # codex は env を渡さないので、agent socket だけ明示的に通す
    "shell_environment_policy.set.SSH_AUTH_SOCK=${lib.escapeShellArg sshAuthSock}"
  ];

  awsWrapper = pkgs.writeShellScript "aws-sandbox-notice" ''
    ${builtins.readFile ../settings/aws-sandbox-notice.sh}
    exec ${pkgs.awscli2}/bin/aws "$@"
  '';

  claudeWrapper = pkgs.writeShellScript "claude-sandbox" ''
    set -eu
    real=${lib.escapeShellArg "${home}/.local/bin/claude"}
    [ -x "$real" ] || { echo "ai-sandbox: $real not found" >&2; exit 127; }
    export SSH_AUTH_SOCK=${lib.escapeShellArg sshAuthSock}
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
    ".config/ai-sandbox/bin/aws".source = awsWrapper;
    ".config/ai-sandbox/bin/claude".source = claudeWrapper;
    ".config/ai-sandbox/bin/codex".source = codexWrapper;
  };
}
