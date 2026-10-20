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
    "${home}/.terraform.d/credentials.tfrc.json"
    "${home}/.npmrc"
    "${home}/.local/share/opencode"
    "${home}/.claude.json"
    "${home}/.zsh_history"
    "${home}/.config/nix/nix.conf"
  ];

  # 署名鍵は agent が保持するので sandbox に鍵ファイルを見せる必要はない
  sshAuthSock = config.home.sessionVariables.SSH_AUTH_SOCK;

  # sandbox からの永続化経路 (自動実行・自己書き換え・プロンプト注入) を塞ぐ
  persistence = [
    "${home}/Library/LaunchAgents"
    "/Library/LaunchAgents"
    "/Library/LaunchDaemons"
    "${home}/.zshrc"
    "${home}/.zshenv"
    "${home}/.zprofile"
    "${home}/.bashrc"
    "${home}/.bash_profile"
    "${home}/.profile"
    "${home}/.config/git/hooks"
    "${home}/.claude/CLAUDE.md"
    "${home}/.codex/AGENTS.md"
    "${home}/.config/opencode/AGENTS.md"
    "${home}/.pi/agent/APPEND_SYSTEM.md"
    "${home}/.claude/settings.json"
    "${home}/.codex/config.toml"
    "${home}/.config/opencode/opencode.json"
    "${home}/.config/ai-sandbox"
    "${home}/.config/claude/sandbox.json"
  ];

  # codex は 1 path 1 verdict なので、自分が読む設定は write だけ deny できない
  codexReadable = [
    "${home}/.codex/AGENTS.md"
    "${home}/.codex/config.toml"
    "${home}/.config/ai-sandbox"
  ];
  codexPersistence = lib.filter (p: !builtins.elem p codexReadable) persistence;

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
  // lib.genAttrs codexPersistence (_: "deny");
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

  awsWrapper = pkgs.writeShellScript "aws-sandbox" ''
    set -eu
    real=${lib.escapeShellArg "${pkgs.awscli2}/bin/aws"}
    sandboxed=0
    for name in \
      CLAUDE_CODE_SANDBOXED \
      CLAUDE_CODE_SANDBOX \
      CLAUDE_SANDBOX \
      CLAUDE_SANDBOXED \
      CODEX_SANDBOX \
      CODEX_SANDBOXED \
      SANDBOX_RUNTIME; do
      marker=$(printenv "$name" 2>/dev/null || true)
      case "$marker" in "" | 0 | false | no) ;; *) sandboxed=1 ;; esac
    done
    if [ "$sandboxed" -eq 0 ] && [ -e "$HOME/.aws" ] && [ ! -r "$HOME/.aws" ]; then
      sandboxed=1
    fi
    if [ "$sandboxed" -eq 0 ]; then
      if ! error=$(ls -A "$HOME/.aws" 2>&1 >/dev/null); then
        case "$error" in
          *"Operation not permitted"* | *"Permission denied"*) sandboxed=1 ;;
        esac
      fi
    fi
    if [ "$sandboxed" -eq 1 ]; then
      echo "ai-sandbox: ~/.aws is blocked inside the sandbox; AWS CLI cannot read profiles or SSO tokens. If config is present and SSO is valid, rerun outside the sandbox." >&2
    fi
    exec "$real" "$@"
  '';
in
{
  # claude/codex は自己更新する binary なので PATH を乗っ取らず、専用 dir を先頭に足す。
  # aws は sandbox の ~/.aws 制限を起動時に通知するため同じ dir で包む。
  # zsh の path は順序が意味を持つため、重複除去で先頭固定する。
  programs.zsh.initContent = lib.mkAfter ''
    typeset -U path PATH
    path=("$HOME/.config/ai-sandbox/bin" $path)
  '';

  home.file = {
    ".config/claude/sandbox.json".text = builtins.toJSON claudeSettings;
    ".config/ai-sandbox/bin/claude".source = claudeWrapper;
    ".config/ai-sandbox/bin/codex".source = codexWrapper;
    ".config/ai-sandbox/bin/aws".source = awsWrapper;
  };
}
