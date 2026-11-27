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
    # gh-intel が出す例外の許可 (X-Gh-Intel-Permit) を検証する公開鍵。値は https://gh-intel.com/api/permit-keys が返す
    # (gh-intel docs/specs/pep-posture.md §6、KMS alias/gh-intel-permit)。鍵を回したらここも替える
    posture.permit_keys = [ "spljO4qzLhxFA/WUK7dEmZta86io58zehFQHwfsYqWU=" ];
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
    # token を他の端末に渡さないよう、各端末が自分の loopback で hub を動かす (docs/security/threat-model.md F2)
    hub.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.client.enable;
      description = "Run a gypxy hub on this host's loopback.";
    };
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
      default = "http://127.0.0.1:${toString port}";
    };
    owners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "gh-intel"
      ];
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.client.enable {
      # gh は GH_HOST に https でしか繋がないため loopback の hub を使えない。gh は github.com に直接繋ぎ、git だけ hub を通す
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

    (lib.mkIf (cfg.hub.enable && pkgs.stdenv.hostPlatform.isDarwin) {
      launchd.agents.gypxy = {
        enable = true;
        config = {
          Label = "dev.egahika.gypxy";
          ProgramArguments = [ "${run}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/gypxy.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/gypxy.log";
        };
      };
    })

    (lib.mkIf (cfg.hub.enable && pkgs.stdenv.hostPlatform.isLinux) {
      systemd.user.services.gypxy = {
        Unit = {
          Description = "gypxy GitHub reverse proxy (loopback hub)";
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
