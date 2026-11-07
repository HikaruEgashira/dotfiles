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

  # aqua-proxy は aqua 本体と global config / policy が無いと local registry の package を解決できない
  aquaEnv = lib.concatStringsSep "\n" (
    [ "export PATH=${pkgs.aqua}/bin:$PATH" ]
    ++ lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") (
      lib.filterAttrs (k: _: lib.hasPrefix "AQUA_" k) config.home.sessionVariables
    )
  );
  aquaBin = "${config.xdg.dataHome}/aquaproj-aqua/bin";

  writable = [
    home
    "/tmp"
    "/private/tmp"
    "/private/var/folders"
    "/usr/local"
  ];

  secrets = [
    "${home}/.ssh"
    "${home}/.gnupg"
    "${home}/.hermes/.env"
    "${home}/.netrc"
    "${home}/.git-credentials"
    "${home}/.kube"
    "${home}/.config/gh/hosts.yml"
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
    "${home}/.local/share/ghtkn"
    # socket は許可するが、暗号化 token store は sandbox に読ませない
    "${config.xdg.cacheHome}/ghtkn/agent"
    "${home}/.local/share/artex/local.env"
    "${home}/.local/share/artex/artex-secrets"
    # プラグイン名が可変なため、秘密を含まない設定も含めてディレクトリ全体を拒否する。
    "${home}/.config/herdr/plugins/config"
    # ~/.aws/config は読ませ、SSO token と credential cache だけ broker (aws-cred-agent) の裏に隠す
    "${home}/.aws/sso"
    "${home}/.aws/cli"
    "${home}/.aws/credentials"
    "${home}/.aws/login"
  ];
  # ~/.cache/hikaevi/*.json は hikaevi[bot] の installation token で、sandbox の gh wrapper が使う前提なので deny しない

  # 署名専用 agent だけを SSH_AUTH_SOCK として見せ、認証鍵の agent には繋がせない
  sshAuthSock = config.home.sessionVariables.SSH_SIGN_AUTH_SOCK;

  # allowAllUnixSockets は docker.sock 等まで開くため、ghtkn / ssh agent / aws broker だけを名前で許可する。
  unixSockets = [
    "${config.xdg.cacheHome}/ghtkn/agent.sock"
    sshAuthSock
    "${config.xdg.cacheHome}/aws-cred/agent.sock"
  ];
  unixSocketsToml = "{${lib.concatMapStringsSep "," (p: ''"${p}"="allow"'') unixSockets}}";

  # network proxy 有効時は domain も明示許可が要る。push と gh api と AWS API の最小集合。
  codexDomains = [
    "github.com"
    "api.github.com"
    "*.amazonaws.com"
  ];
  codexDomainsToml = "{${lib.concatMapStringsSep "," (d: ''"${d}"="allow"'') codexDomains}}";

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
        allowUnixSockets = unixSockets;
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
  # codex は credential dir を path 非依存で組み込み deny するため、~/.aws/config だけ read で上書きし、secrets の子 path deny を優先させる
  codexFilesystem = {
    "/" = "read";
    "${home}/.aws" = "read";
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
    "permissions.dev.network={enabled=true,unix_sockets=${unixSocketsToml},domains=${codexDomainsToml}}"
    # codex は env を渡さないので、agent socket だけ明示的に通す
    "shell_environment_policy.set.SSH_AUTH_SOCK=${lib.escapeShellArg sshAuthSock}"
    "check_for_update_on_startup=false"
  ];

  # エージェントの gh は hikaevi[bot] の installation token で叩き、個人の 5,000/h を消費しない。
  # 対象 owner は hikaevi の allowed_owners、-R/--repo を優先し、無ければ cwd の origin から引く。
  # token 発行に失敗したとき・明示 GH_TOKEN があるときは個人認証のまま通す。
  ghWrapper = pkgs.writeShellScript "gh-hikaevi" ''
    set -eu
    real=${lib.escapeShellArg "${home}/.nix-profile/bin/gh"}
    minter=${lib.escapeShellArg "${home}/ghq/github.com/HikaruEgashira/hikaevi/scripts/local-token.mjs"}
    if [ -z "''${GH_TOKEN:-}" ] && [ -f "$minter" ]; then
      owner=""
      prev=""
      for a in "$@"; do
        case "$prev" in -R|--repo) owner=''${a%%/*} ;; esac
        case "$a" in --repo=*) r=''${a#--repo=}; owner=''${r%%/*} ;; esac
        prev=$a
      done
      [ -n "$owner" ] || owner=$(git remote get-url origin 2>/dev/null | sed -nE 's#^.*github\.com[:/]([^/]+)/.*$#\1#p')
      case "$owner" in
        HikaruEgashira|plenoai)
          if token=$(node "$minter" "$owner" 2>/dev/null); then export GH_TOKEN="$token"; fi ;;
      esac
    fi
    exec "$real" "$@"
  '';

  claudeWrapper = pkgs.writeShellScript "claude-sandbox" ''
    set -eu
    real=${lib.escapeShellArg "${aquaBin}/claude"}
    [ -x "$real" ] || { echo "ai-sandbox: $real not found" >&2; exit 127; }
    ${aquaEnv}
    # 版は aqua.yaml の pin が正史なので、自己更新で検証外の binary に置き換わらないようにする
    export DISABLE_AUTOUPDATER=1
    export SSH_AUTH_SOCK=${lib.escapeShellArg sshAuthSock}
    # export した PAT や text backend を sandbox に継承させず、常に agent socket 経由に固定する
    unset GHTKN_GITHUB_TOKEN GHTKN_BACKEND GHTKN_TEXT_BACKEND_DIR
    exec "$real" --settings ${lib.escapeShellArg "${config.xdg.configHome}/claude/sandbox.json"} "$@"
  '';

  codexWrapper = pkgs.writeShellScript "codex-sandbox" ''
    set -eu
    real=${lib.escapeShellArg "${aquaBin}/codex"}
    [ -x "$real" ] || { echo "ai-sandbox: $real not found" >&2; exit 127; }
    ${aquaEnv}
    exec "$real" ${lib.concatMapStringsSep " " (a: "-c ${lib.escapeShellArg a}") codexArgs} "$@"
  '';
in
{
  # zsh の path は順序が意味を持つため、重複除去で wrapper dir を先頭固定する。
  programs.zsh.initContent = lib.mkAfter ''
    typeset -U path PATH
    path=("$HOME/.config/ai-sandbox/bin" $path)
  '';

  home.file = {
    ".config/claude/sandbox.json".text = builtins.toJSON claudeSettings;
    ".config/ai-sandbox/bin/claude".source = claudeWrapper;
    ".config/ai-sandbox/bin/codex".source = codexWrapper;
    ".config/ai-sandbox/bin/gh".source = ghWrapper;
  };
}
