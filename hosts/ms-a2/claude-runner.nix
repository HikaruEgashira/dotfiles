# claude self-hosted-runner を専用の system user で動かす (旧: hikae の手作り systemd user unit)。
# リモートのセッションは runner と同じ uid で動くため、hikae の home (~/.claude, ~/.ssh, ~/.aws など) を読めないようにする。
# 初回だけ: environment secret を root 所有 0600 の /etc/claude-runner/env (KEY=VALUE 形式) に置く。
# 移行後に hikae 側の ~/.config/systemd/user/claude-self-hosted-runner.service、~/.config/claude-runner、
# ~/ghq/_sessions、~/ghq/.host-config-snapshot-* を削除する。
{ config, lib, pkgs, ... }:
let
  home = "/var/lib/claude-runner";
  # health / metrics の待ち受けポート。firewall で閉じたままにする (ホスト外へ公開しない)
  healthPort = 8080;
  start = pkgs.writeShellScript "claude-self-hosted-runner" ''
    set -a
    # shellcheck disable=SC1091
    . "$CREDENTIALS_DIRECTORY/env"
    set +a
    exec ${lib.getExe pkgs.claude-code} self-hosted-runner
  '';
in
{
  assertions = [
    {
      assertion =
        !(lib.elem healthPort config.networking.firewall.allowedTCPPorts)
        && config.networking.firewall.enable;
      message = "claude-runner の health/metrics (:${toString healthPort}) を firewall で開けない";
    }
  ];

  users.groups.claude-runner = { };
  users.users.claude-runner = {
    isSystemUser = true;
    group = "claude-runner";
    inherit home;
    createHome = false;
  };

  systemd.tmpfiles.rules = [
    "d /etc/claude-runner 0700 root root -"
  ];

  systemd.services.claude-self-hosted-runner = {
    description = "Claude self-hosted runner";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bash
      coreutils
      git
    ];
    environment.HOME = home;
    unitConfig.ConditionPathExists = "/etc/claude-runner/env";
    serviceConfig = {
      User = "claude-runner";
      Group = "claude-runner";
      StateDirectory = "claude-runner";
      StateDirectoryMode = "0700";
      WorkingDirectory = home;
      LoadCredential = "env:/etc/claude-runner/env";
      ExecStart = start;
      Restart = "always";
      RestartSec = 5;
      TimeoutStopSec = 100;
      NoNewPrivileges = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
    };
  };
}
