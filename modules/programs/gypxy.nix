{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.gypxy;
  stateDir = "${config.xdg.stateHome}/gypxy";
  aquaRoot = "${config.xdg.dataHome}/aquaproj-aqua";
  port = 9300;
  adminPort = 9301;

  ghCredentialHelper =
    if pkgs ? ghtkn then
      "!${pkgs.ghtkn}/bin/ghtkn git-credential"
    else
      "!${pkgs.gh}/bin/gh auth git-credential";

  # webhook は Funnel が無いと GitHub から届かないため、routes で mirror 対象を宣言して covered にする
  hubConfig = (pkgs.formats.json { }).generate "gypxy.json" {
    listen = "127.0.0.1:${toString port}";
    public_url = cfg.url;
    data_dir = stateDir;
    git = {
      mirror = true;
      mirror_scope = "covered";
      routes = map (owner: {
        match = "${owner}/*";
        fetch = [ "github" ];
      }) cfg.owners;
    };
    intel = {
      findings_file = "${stateDir}/findings.jsonl";
      audit_file = "${stateDir}/audit.jsonl";
      resolve_actor = true;
    };
    policy.deny = [
      {
        operation = "repos/delete";
        reason = "Repositories are not deleted through the proxy.";
      }
    ];
    admin = {
      listen = "127.0.0.1:${toString adminPort}";
      token_file = "${stateDir}/admin-token";
    };
    # tailscale serve が TLS を終端して loopback から転送する
    trusted_proxies = [ "127.0.0.1/32" ];
    log_level = "info";
  };

  run = pkgs.writeShellScript "gypxy-run" ''
    set -eu
    umask 077
    ${pkgs.coreutils}/bin/install -d -m 0700 ${stateDir}
    [ -s ${stateDir}/admin-token ] || ${pkgs.openssl}/bin/openssl rand -hex 32 >${stateDir}/admin-token
    export PATH=${lib.makeBinPath [ pkgs.git ]}:$PATH
    export AQUA_GLOBAL_CONFIG=${config.xdg.configHome}/aqua/aqua.yaml
    export AQUA_POLICY_CONFIG=${config.xdg.configHome}/aqua/aqua-policy.yaml
    export AQUA_ROOT_DIR=${aquaRoot}
    exec ${aquaRoot}/bin/gypxy -config ${hubConfig}
  '';
in
{
  options.programs.gypxy = {
    hub.enable = lib.mkEnableOption "gypxy hub that serves the tailnet";
    client.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Route git traffic for the listed owners through the hub.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://ms-a2.tailc30b81.ts.net";
    };
    owners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "sisaku-security" ];
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.client.enable {
      programs.git.settings = {
        credential."${cfg.url}".helper = [
          ""
          ghCredentialHelper
        ];
        url = lib.listToAttrs (
          map (owner: {
            name = "${cfg.url}/${owner}/";
            value.insteadOf = "https://github.com/${owner}/";
          }) cfg.owners
        );
      };
    })

    (lib.mkIf cfg.hub.enable {
      systemd.user.services.gypxy = {
        Unit = {
          Description = "gypxy GitHub reverse proxy (tailnet hub)";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStart = "${run}";
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
