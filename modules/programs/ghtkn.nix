# GitHub 認証を GitHub App の user access token (8h) に統一する。
# 背景: 2026-10-31 に個人の REST quota (5000/h) が別ホストの長期 token に毎時食い潰され、
# 全 OAuth / GitHub App 認可を revoke した。長期 token を端末に置かない構成に切り替える。
# token は agent backend が暗号化して保持し、`gh` wrapper (lib/package-registry.nix) と
# git credential helper (git.nix) が `ghtkn exec` / `ghtkn git-credential` で取り出す。
# refresh token は agent backend でしか使えないため、8h 毎の device flow を避けて
# 自動更新するには agent を launchd で常駐させ、login 後に 1 回 unlock する。
# unlock は passphrase を永続化しない設計なので `ghtkn agent unlock --enable-refresh` を手で実行する。
# linux (WSL) は root が容易に取れる環境なので refresh token を有効化しない (ghauth.sh)。
#
# App の階層 (docs/security/threat-model.md F7):
#   ghtkn-hikae-ops      workflows / actions write。host の terminal から `ghops` 経由でだけ使う。別 agent・別 socket
#   ghtkn-hikae          開発用 (contents / pull_requests / issues)。sandbox の agent も既定 socket から使う
#   ghtkn-hikae-readonly シンクライアント (macbook-air, ms-a2) 用
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.ghtkn;
  home = config.home.homeDirectory;
  inherit (cfg) readonly;
  appName = if readonly then "HikaruEgashira/ghtkn-hikae-readonly" else "HikaruEgashira/ghtkn-hikae";
  opsAppName = "HikaruEgashira/ghtkn-hikae-ops";
  opsDir = builtins.dirOf cfg.opsSocket;
  opsKey = "${config.xdg.dataHome}/ghtkn-ops/key";
  opsConfig = "${config.xdg.configHome}/ghtkn-ops/ghtkn.yaml";
  schema = "# yaml-language-server: $schema=https://raw.githubusercontent.com/suzuki-shunsuke/ghtkn/main/json-schema/ghtkn.json";
  apps =
    if readonly then
      ''
        # 書き込み権限を持たない App。シンクライアントに push 可能な token を置かない
        apps:
          - name: ${appName}
            client_id: Iv23liLdZ6iYl41g70Rp
      ''
    else
      ''
        # App: https://github.com/settings/apps/ghtkn-hikae (Device Flow 有効、HikaruEgashira / plenoai / gh-intel に install)
        apps:
          - name: ${appName}
            client_id: Iv23li4HDmrucWZqsdP4
          # App: ghtkn-potato (account: jarman-potato, gh-intel-e2e / BinaryBaconLabs に install)
          - name: jarman-potato
            client_id: Iv23lifOlYpSnmUdsUuA
      '';
  # ops agent の env。token store / key / socket を既定 agent と分け、sandbox が deny する dir に置く
  opsEnv = {
    GHTKN_CONFIG = opsConfig;
    GHTKN_AGENT_SOCKET = cfg.opsSocket;
    GHTKN_AGENT_TOKEN_DIR = "${opsDir}/agent";
    GHTKN_AGENT_KEY = opsKey;
    GHTKN_APP = opsAppName;
  };
  agentFor = label: log: env: {
    enable = true;
    config = {
      Label = label;
      ProgramArguments = [
        "${pkgs.ghtkn}/bin/ghtkn"
        "agent"
        "start"
      ];
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      StandardOutPath = "${home}/Library/Logs/${log}.log";
      StandardErrorPath = "${home}/Library/Logs/${log}.log";
    }
    // lib.optionalAttrs (env != { }) { EnvironmentVariables = env; };
  };
in
{
  options.dotfiles.ghtkn = {
    readonly = lib.mkEnableOption "the read-only GitHub App as the only ghtkn app (thin client)";
    ops.enable = lib.mkOption {
      type = lib.types.bool;
      default = !readonly && pkgs.stdenv.hostPlatform.isDarwin;
      description = "workflows / actions write を持つ ghtkn-hikae-ops を、sandbox から届かない別 agent で置く";
    };
    opsSocket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${config.xdg.cacheHome}/ghtkn-ops/agent.sock";
      description = "ops agent の socket。ai-sandbox は親 dir ごと deny する";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(readonly && cfg.ops.enable);
          message = "dotfiles.ghtkn.ops.enable は readonly 端末に置けない";
        }
      ];

      xdg.configFile."ghtkn/ghtkn.yaml".text = ''
        ${schema}
        # Client ID は秘密ではない (device flow は client secret を使わない)。
        ${apps}
        backend:
          type: agent
      '';

      # `GHTKN_GITHUB_TOKEN` を export すれば一時的に PAT へ切替できる (configuration.md)。
      home.sessionVariables.GHTKN_APP = appName;

      # 人間が叩く唯一の認証入口。agent の起動と unlock を吸収して device flow へ入る
      home.file.".local/bin/ghauth" = {
        text = builtins.readFile ./ghtkn/ghauth.sh;
        executable = true;
      };

      # `ghtkn agent stop` は exit 0 なので SuccessfulExit=false で crash だけ再起動する
      # linux (WSL) も同じ常駐を systemd user service で持つ。exit 0 の stop では再起動しない
      systemd.user.services.ghtkn-agent = lib.mkIf (pkgs ? ghtkn && pkgs.stdenv.hostPlatform.isLinux) {
        Unit.Description = "ghtkn agent";
        Service = {
          ExecStart = "${pkgs.ghtkn}/bin/ghtkn agent start";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "default.target" ];
      };

      launchd.agents = lib.mkIf (pkgs ? ghtkn && pkgs.stdenv.hostPlatform.isDarwin) {
        ghtkn-agent = agentFor "dev.egahika.ghtkn-agent" "ghtkn-agent" { };
      };
    }

    (lib.mkIf (cfg.ops.enable && pkgs ? ghtkn) {
      # ops App は既定の ghtkn.yaml に載せない。既定 agent (sandbox から届く) が ops の token を持つ経路を作らない
      xdg.configFile."ghtkn-ops/ghtkn.yaml".text = ''
        ${schema}
        # App: https://github.com/settings/apps/ghtkn-hikae-ops (Device Flow 有効、HikaruEgashira / plenoai / gh-intel に install)
        apps:
          - name: ${opsAppName}
            client_id: Iv23li38Or76gNJho0xE
        backend:
          type: agent
      '';

      # `ghops git push` / `ghops gh workflow run ...` / `ghops ghauth` で ops agent に切り替える
      home.file.".local/bin/ghops" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail
          [ "$#" -gt 0 ] || { echo "usage: ghops <git|gh|ghauth> ..." >&2; exit 2; }
          unset GH_TOKEN GITHUB_TOKEN GHTKN_GITHUB_TOKEN GHTKN_BACKEND
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") opsEnv
          )}
          export GHTKN_AGENT_LABEL=dev.egahika.ghtkn-ops-agent
          exec "$@"
        '';
      };

      launchd.agents.ghtkn-ops-agent = agentFor "dev.egahika.ghtkn-ops-agent" "ghtkn-ops-agent" (
        lib.removeAttrs opsEnv [ "GHTKN_APP" ]
      );
    })
  ];
}
