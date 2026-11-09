# SSH の鍵操作を全て自前の ssh-agent 経由にし、認証鍵と署名鍵で agent を分ける。
# launchd の socket ($TMPDIR/.../Listeners) は起動ごとにパスが変わり、GUI 以外では
# SSH_AUTH_SOCK が未設定なので、固定パスの agent を立てて全経路をそこへ寄せる。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  agentSocket = "${home}/.local/state/ssh-agent.sock";
  # sandbox には署名 agent だけを見せ、認証鍵で ssh できないようにする
  signAgentSocket = "${home}/.local/state/ssh-sign-agent.sock";

  # agent と ssh-add の起動順は保証されないので、agent が接続を受け付けるまで待つ。
  # 再起動前の stale socket も -S は真になるため、`ssh-add -l` の exit 2 (接続不可) で判定する
  addKey =
    keyFile:
    pkgs.writeShellScript "ssh-add-key" ''
      for _ in $(seq 30); do
        ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1
        [ $? -ne 2 ] && exec ${pkgs.openssh}/bin/ssh-add ${keyFile}
        sleep 1
      done
      echo "ssh-add: agent not accepting connections at $SSH_AUTH_SOCK" >&2
      exit 1
    '';

  # agent と鍵の対応を 1 箇所に置き、launchd (darwin) と systemd (linux) の両方をここから生成する
  agents = {
    ssh-agent = {
      socket = agentSocket;
      key = "${home}/.ssh/id_ed25519";
    };
    ssh-sign-agent = {
      socket = signAgentSocket;
      key = "${home}/.ssh/id_ed25519_sign";
    };
  };

  agentArgs = socket: [
    "${pkgs.python3}/bin/python3"
    "${../../scripts/ssh-agent-start.py}"
    socket
    "${pkgs.openssh}/bin/ssh-agent"
  ];

  agent = name: socket: {
    enable = true;
    config = {
      Label = "dev.egahika.${name}";
      ProgramArguments = agentArgs socket;
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${home}/Library/Logs/${name}.log";
      StandardErrorPath = "${home}/Library/Logs/${name}.log";
    };
  };

  loader = name: socket: keyFile: {
    enable = true;
    config = {
      Label = "dev.egahika.${name}";
      ProgramArguments = [ "${addKey keyFile}" ];
      EnvironmentVariables.SSH_AUTH_SOCK = socket;
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/${name}.log";
      StandardErrorPath = "${home}/Library/Logs/${name}.log";
    };
  };
in
{
  launchd.agents = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    ssh-agent = agent "ssh-agent" agentSocket;
    ssh-add = loader "ssh-add" agentSocket agents.ssh-agent.key;
    ssh-sign-agent = agent "ssh-sign-agent" signAgentSocket;
    ssh-sign-add = loader "ssh-sign-add" signAgentSocket agents.ssh-sign-agent.key;
  };

  # 鍵の投入は agent 起動直後の ExecStartPost で行い、launchd の別 job 相当を不要にする
  systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mapAttrs (name: a: {
      Unit.Description = "dedicated ssh-agent (${name})";
      Service = {
        ExecStart = lib.escapeShellArgs (agentArgs a.socket);
        ExecStartPost = "${pkgs.coreutils}/bin/env SSH_AUTH_SOCK=${a.socket} ${addKey a.key}";
        Restart = "always";
      };
      Install.WantedBy = [ "default.target" ];
    }) agents
  );

  home.sessionVariables.SSH_SIGN_AUTH_SOCK = signAgentSocket;
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

  # hm-session-vars は login shell では読まれないため、envExtra でも同じ値を固定する。
  # sandbox wrapper が署名 socket を指定して起動した shell では上書きしない
  programs.zsh.envExtra = lib.mkAfter ''
    [ "''${SSH_AUTH_SOCK-}" = ${lib.escapeShellArg signAgentSocket} ] || export SSH_AUTH_SOCK=${lib.escapeShellArg agentSocket}
  '';
}
