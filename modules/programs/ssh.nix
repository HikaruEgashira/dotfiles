# SSH の鍵操作を全て自前の ssh-agent 経由にする。
# launchd の socket ($TMPDIR/.../Listeners) は起動ごとにパスが変わり、GUI 以外では
# SSH_AUTH_SOCK が未設定なので、固定パスの agent を 1 本立てて全経路をそこへ寄せる。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  agentSocket = "${home}/.local/state/ssh-agent.sock";
  keyFile = "${home}/.ssh/id_ed25519";

  # agent と ssh-add の起動順は保証されないので、socket が生えるまで待つ
  addKey = pkgs.writeShellScript "ssh-add-key" ''
    for _ in $(seq 30); do
      [ -S "$SSH_AUTH_SOCK" ] && exec ${pkgs.openssh}/bin/ssh-add ${keyFile}
      sleep 1
    done
    echo "ssh-add: agent socket not found at $SSH_AUTH_SOCK" >&2
    exit 1
  '';
in
{
  launchd.agents = {
    ssh-agent = {
      enable = true;
      config = {
        Label = "dev.egahika.ssh-agent";
        ProgramArguments = [
          "${pkgs.python3}/bin/python3"
          "${../../scripts/ssh-agent-start.py}"
          agentSocket
          "${pkgs.openssh}/bin/ssh-agent"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${home}/Library/Logs/ssh-agent.log";
        StandardErrorPath = "${home}/Library/Logs/ssh-agent.log";
      };
    };
    ssh-add = {
      enable = true;
      config = {
        Label = "dev.egahika.ssh-add";
        ProgramArguments = [ "${addKey}" ];
        EnvironmentVariables.SSH_AUTH_SOCK = agentSocket;
        RunAtLoad = true;
        StandardOutPath = "${home}/Library/Logs/ssh-add.log";
        StandardErrorPath = "${home}/Library/Logs/ssh-add.log";
      };
    };
  };

  home.sessionVariables.SSH_AUTH_SOCK = agentSocket;

  # 鍵ファイルへのフォールバックを潰し、接続も署名も agent だけを見るようにする
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      HashKnownHosts yes
    '';
    settings = {
      "*" = {
        IdentityAgent = agentSocket;
        IdentityFile = [ "none" ];
      };
      "*.exe.xyz" = {
        Compression = true;
        TCPKeepAlive = "yes";
        ServerAliveInterval = 15;
        ServerAliveCountMax = 6;
        IPQoS = "lowdelay throughput";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/mux-%r@%h:%p";
        ControlPersist = "10m";
      };
      vultr = {
        HostName = "45.76.196.181";
        User = "linuxuser";
      };
      vultr2 = {
        HostName = "45.76.196.181";
        User = "linuxuser";
        LocalForward = [
          {
            bind.port = 12345;
            host.address = "2001:19f0:7001:5e49:5400:04ff:fef5:64b7";
            host.port = 22;
          }
        ];
      };
      "github.com" = {
        HostName = "ssh.github.com";
        User = "git";
        Port = 443;
        TCPKeepAlive = "yes";
        ServerAliveInterval = 15;
        ServerAliveCountMax = 6;
      };
    };
  };

  # hm-session-vars は login shell では読まれないため、envExtra でも同じ値を固定する
  programs.zsh.envExtra = lib.mkAfter ''
    export SSH_AUTH_SOCK=${lib.escapeShellArg agentSocket}
  '';
}
