{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/share/artex";
  # socket は専用 0700 dir に置き、ai-sandbox の unixSockets allowlist に載せないことで sandbox 内 agent から遮断する
  socketDir = "${stateDir}/run";
  pgHba = ./artex/pg_hba.conf;
  # binary・data・secrets は stateful (stateDir)、起動条件だけ宣言管理する。待受は loopback 限定で受信は公開しない
  run = pkgs.writeShellScript "artex-run" ''
    set -eu
    # server が exec する aws (MicroVM 操作) / npx (MCP) / rg を launchd の最小 PATH に足す
    export PATH=${
      lib.makeBinPath [
        pkgs.awscli2
        pkgs.nodejs_24
        pkgs.ripgrep
      ]
    }:/usr/bin:/bin:/usr/sbin:/sbin
    . ${./artex/load-env.sh}
    load_env_file ${stateDir}/local.env
    exec ${stateDir}/bin/artex -addr 127.0.0.1:8787 -proxy 127.0.0.1:8788 \
      -data ${stateDir}/artex/data -keys ${stateDir}/artex-secrets/jwt
  '';
  # pg_hba.conf は PGDATA 内の stateful file なので、起動毎に repo 宣言と比較し drift を修復してから postgres を起動する。
  # launchd の SIGTERM は postgres では smart shutdown (接続が切れるまで待つ) になり ExitTimeOut で SIGKILL されるため、
  # wrapper が受けて SIGINT (fast shutdown) に変換する
  runPostgres = pkgs.writeShellScript "artex-postgres-run" ''
    set -eu
    ${pkgs.coreutils}/bin/install -d -m 0700 ${socketDir}
    if ! ${pkgs.diffutils}/bin/cmp -s ${pgHba} ${stateDir}/pg/pg_hba.conf; then
      echo "pg_hba.conf drifted from declaration; restoring" >&2
      ${pkgs.coreutils}/bin/install -m 0600 ${pgHba} ${stateDir}/pg/pg_hba.conf
    fi
    ${pkgs.postgresql_16}/bin/postgres -D ${stateDir}/pg -k ${socketDir} -c listen_addresses= -p 5432 &
    pg=$!
    trap 'kill -INT "$pg"' TERM INT
    wait "$pg" || true
    trap - TERM INT
    wait "$pg"
  '';
in
{
  launchd.agents.artex-postgres = {
    enable = true;
    config = {
      Label = "dev.egahika.artex-postgres";
      ProgramArguments = [ "${runPostgres}" ];
      RunAtLoad = true;
      KeepAlive = true;
      ExitTimeOut = 60;
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
