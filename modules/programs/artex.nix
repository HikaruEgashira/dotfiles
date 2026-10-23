{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/share/artex";
  # binary・data・secrets は stateful (stateDir)、起動条件だけ宣言管理する。待受は loopback 限定で受信は公開しない
  run = pkgs.writeShellScript "artex-run" ''
    # server が exec する aws (MicroVM 操作) / npx (MCP) / rg を launchd の最小 PATH に足す
    export PATH=${
      lib.makeBinPath [
        pkgs.awscli2
        pkgs.nodejs_24
        pkgs.ripgrep
      ]
    }:/usr/bin:/bin:/usr/sbin:/sbin
    set -a
    . ${stateDir}/local.env
    set +a
    exec ${stateDir}/bin/artex -addr 127.0.0.1:8787 -proxy 127.0.0.1:8788 \
      -data ${stateDir}/artex/data -keys ${stateDir}/artex-secrets/jwt
  '';
in
{
  launchd.agents.artex-postgres = {
    enable = true;
    config = {
      Label = "dev.egahika.artex-postgres";
      ProgramArguments = [
        "${pkgs.postgresql_16}/bin/postgres"
        "-D"
        "${stateDir}/pg"
        "-k"
        stateDir
        "-h"
        "127.0.0.1"
        "-p"
        "5432"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${stateDir}/pg.log";
      StandardErrorPath = "${stateDir}/pg.log";
    };
  };

  launchd.agents.artex = {
    enable = true;
    config = {
      Label = "dev.egahika.artex";
      ProgramArguments = [ "${run}" ];
      WorkingDirectory = stateDir;
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${stateDir}/artex.log";
      StandardErrorPath = "${stateDir}/artex.log";
    };
  };
}
