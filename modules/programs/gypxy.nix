{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.gypxy;
  stateDir = "${config.xdg.stateHome}/gypxy";
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
    exec ${lib.getExe cfg.package} -config ${hubConfig}
  '';
in
{
  options.programs.gypxy = {
    hub.enable = lib.mkEnableOption "gypxy hub that serves the tailnet";
    # 起動時に取得しない。store の固定 hash の asset を使い、版を上げると activation が unit を再起動する
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.callPackage ./gypxy-package.nix { };
    };
    client.enable = lib.mkOption {
      type = lib.types.bool;
      # hub が止まると対象 owner の git が全端末で失敗する。その間は false にして適用し直す
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
      # gh wrapper (lib/package-registry.nix) が対象 owner のときだけ GH_HOST に hub を入れる
      home.sessionVariables = {
        GYPXY_GH_HOST = lib.removePrefix "https://" cfg.url;
        GYPXY_OWNERS = lib.concatStringsSep " " cfg.owners;
      };
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
