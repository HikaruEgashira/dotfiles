# Fleet (端末管理) サーバー。tailnet 内だけに公開し、dotfiles の適用と DNS profile の配布を担う
{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = "/var/lib/fleet";
  port = 8412;
  publicPort = 8443;
  fleetUrl = "https://ms-a2.tailc30b81.ts.net:${toString publicPort}";
  redisPort = 6380;

  # DB パスワードと MDM 用サーバー鍵は repo に置かず、初回起動時にこの host で作る
  secrets = pkgs.writeShellScript "fleet-secrets" ''
    set -eu
    umask 077
    if [ ! -s ${stateDir}/env ]; then
      pw=$(${pkgs.openssl}/bin/openssl rand -hex 32)
      key=$(${pkgs.openssl}/bin/openssl rand -base64 32)
      printf 'FLEET_MYSQL_PASSWORD=%s\nFLEET_SERVER_PRIVATE_KEY=%s\n' "$pw" "$key" > ${stateDir}/env
    fi
    pw=$(${pkgs.gnused}/bin/sed -n 's/^FLEET_MYSQL_PASSWORD=//p' ${stateDir}/env)
    ${config.services.mysql.package}/bin/mysql -u root -e \
      "CREATE USER IF NOT EXISTS 'fleet'@'127.0.0.1' IDENTIFIED BY '$pw'; ALTER USER 'fleet'@'127.0.0.1' IDENTIFIED BY '$pw'; GRANT ALL PRIVILEGES ON fleet.* TO 'fleet'@'127.0.0.1';"
  '';

  fleetEnv = {
    FLEET_MYSQL_ADDRESS = "127.0.0.1:3306";
    FLEET_MYSQL_DATABASE = "fleet";
    FLEET_MYSQL_USERNAME = "fleet";
    FLEET_REDIS_ADDRESS = "127.0.0.1:${toString redisPort}";
    FLEET_SERVER_ADDRESS = "127.0.0.1:${toString port}";
    # TLS は tailscale serve が tailnet の証明書で終端する
    FLEET_SERVER_TLS = "false";
    FLEET_LOGGING_JSON = "true";
  };
in
{
  services = {
    mysql = {
      enable = true;
      package = pkgs.mysql84;
      ensureDatabases = [ "fleet" ];
      settings.mysqld = {
        bind-address = "127.0.0.1";
        mysqlx = 0;
      };
    };

    redis.servers.fleet = {
      enable = true;
      bind = "127.0.0.1";
      port = redisPort;
    };
  };

  systemd = {
    services = {
      fleet-secrets = {
        description = "Generate Fleet database credentials and server key";
        after = [ "mysql.service" ];
        requires = [ "mysql.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "fleet";
          StateDirectoryMode = "0700";
          ExecStart = secrets;
        };
      };

      fleet = {
        description = "Fleet device management server";
        after = [
          "fleet-secrets.service"
          "redis-fleet.service"
        ];
        requires = [
          "fleet-secrets.service"
          "redis-fleet.service"
        ];
        wantedBy = [ "multi-user.target" ];
        environment = fleetEnv;
        serviceConfig = {
          EnvironmentFile = "${stateDir}/env";
          ExecStartPre = "${pkgs.fleet}/bin/fleet prepare db --no-prompt";
          ExecStart = "${pkgs.fleet}/bin/fleet serve";
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = 10;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };

      fleet-serve = {
        description = "Expose Fleet on the tailnet over HTTPS";
        after = [
          "tailscaled.service"
          "fleet.service"
        ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=${toString publicPort} http://127.0.0.1:${toString port}";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };

      fleet-controller = {
        description = "Roll CI-green dotfiles main out to enrolled Macs";
        path = [ pkgs.git ];
        after = [ "fleet.service" ];
        requires = [ "fleet.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.python3}/bin/python3 -I ${../../scripts/fleet-controller.py} ${stateDir} http://127.0.0.1:${toString port} ${fleetUrl} ${../../scripts/fleet/dotfiles-apply.sh} /var/lib/fleet-enroll/secret";
        };
      };
    };

    timers = {
      fleet-controller = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2m";
          OnUnitActiveSec = "5m";
        };
      };
    };
  };

  # Mac の登録時に wheel が ssh 越しに enroll secret を読む
  systemd.tmpfiles.rules = [ "d /var/lib/fleet-enroll 0750 root wheel -" ];

  environment.etc."fleet/url".text = fleetUrl;
}
