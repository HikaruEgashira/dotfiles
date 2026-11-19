# claude self-hosted-runner を作業者の home から切り離した専用ユーザーで動かす
# 初回だけ: runner の環境変数 (トークン等) を root 0400 の /etc/claude-runner/env に置く。repo には置かない
{ pkgs, lib, ... }:
{
  users = {
    groups.claude-runner = { };
    users.claude-runner = {
      isSystemUser = true;
      group = "claude-runner";
      home = "/var/lib/claude-runner";
      shell = pkgs.bashInteractive;
    };
  };

  systemd.tmpfiles.rules = [ "d /etc/claude-runner 0700 root root -" ];

  systemd.services.claude-self-hosted-runner = {
    description = "Claude Code self-hosted runner";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bash
      coreutils
      git
      gnugrep
      openssh
    ];
    environment.HOME = "/var/lib/claude-runner";
    unitConfig.ConditionPathExists = "/etc/claude-runner/env";
    serviceConfig = {
      User = "claude-runner";
      Group = "claude-runner";
      ExecStart = "${lib.getExe pkgs.claude-code} self-hosted-runner";
      # systemd が root で読むので、secret は claude-runner から直接読めない
      EnvironmentFile = "/etc/claude-runner/env";
      StateDirectory = "claude-runner";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/claude-runner";
      Restart = "always";
      RestartSec = 10;
      TimeoutStopSec = 100;
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
    };
  };

  # health / metrics (:8080) は全インターフェースで待ち受けるので、loopback 以外からは常に落とす
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw -p tcp --dport 8080 ! -i lo -j DROP
      ip6tables -I nixos-fw -p tcp --dport 8080 ! -i lo -j DROP
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -p tcp --dport 8080 ! -i lo -j DROP || true
      ip6tables -D nixos-fw -p tcp --dport 8080 ! -i lo -j DROP || true
    '';
  };
}
