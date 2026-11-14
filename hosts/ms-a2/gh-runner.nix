# HikaruEgashira の self-hosted runner ホスト (旧: Windows 上の WSL ディストリ gh-runner)。
# ジョブごとの使い捨て環境 (systemd-nspawn + overlayfs + 専用 netns + 専用 dockerd) の仕組み自体は
# iac-aws/projects/local-runners/linux にあり、gh-runner-sync.timer が iac-aws main を /opt/gh-runner へ反映する。
# ここでは WSL 時代に install.sh が apt / systemd unit で入れていたホスト側の前提だけを宣言する。
# 初回だけ: iac-aws の linux/install.sh を root で実行 → ghtkn agent unlock / ghtkn auth → dispatcher 起動 (README 参照)
{ pkgs, ... }:
let
  # スクリプト群 (slot.sh / sync.sh / build-base-*.sh / jobnet.sh など) が呼ぶコマンド
  tools = with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    gnutar
    gzip
    xz
    zstd
    unzip
    curl
    jq
    python3
    util-linux
    iproute2
    iptables
    procps
    systemd
    debootstrap
    docker
    ghtkn
  ];
  ghtknEnv = {
    HOME = "/root";
    GHTKN_BACKEND = "agent";
    GHTKN_AGENT_SOCKET = "/root/.cache/ghtkn/agent.sock";
  };
  # ジョブの PATH 先頭 (/nix/var/nix/profiles/default/bin) と slot-test が参照する nix
  jobNix = pkgs.buildEnv {
    name = "gh-runner-job-nix";
    paths = [
      pkgs.nix
      pkgs.cachix
    ];
  };
in
{
  environment.systemPackages = tools;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # ジョブは GitHub-hosted と同じ runner (uid 1001) で動く。nix-daemon は接続元を uid で識別するため同じ uid を用意する
  users.groups.runner.gid = 1001;
  users.users.runner = {
    isSystemUser = true;
    uid = 1001;
    group = "runner";
  };

  nix.settings = {
    # GitHub-hosted の install-nix-action (set_as_trusted_user) と揃える
    trusted-users = [ "runner" ];
    min-free = 10737418240;
    max-free = 32212254720;
  };

  # Docker Hub プルスルーキャッシュ。ジョブ内の dockerd が registry-mirrors で 10.201.0.1:5000 を見る
  virtualisation.docker = {
    enable = true;
    daemon.settings.log-driver = "local";
  };
  virtualisation.oci-containers = {
    backend = "docker";
    containers.hub-mirror = {
      image = "public.ecr.aws/docker/library/registry:2";
      ports = [ "10.201.0.1:5000:5000" ];
      environment = {
        REGISTRY_PROXY_REMOTEURL = "https://registry-1.docker.io";
        REGISTRY_STORAGE_DELETE_ENABLED = "true";
      };
      volumes = [ "/var/lib/gh-runner/hub-mirror:/var/lib/registry" ];
    };
  };
  systemd.services.docker-hub-mirror = {
    after = [ "gh-runner-netns.service" ];
    requires = [ "gh-runner-netns.service" ];
  };

  systemd.tmpfiles.rules = [
    "d /etc/gh-runner 0755 root root -"
    "d /etc/gh-runner/secrets 0700 root root -"
    "d /opt/gh-runner 0755 root root -"
    "d /var/lib/gh-runner 0755 root root -"
    "d /var/lib/gh-runner/work 0755 root root -"
    "d /w 0755 root root -"
    "L+ /nix/var/nix/profiles/default - - - - ${jobNix}"
  ];

  systemd.services = {
    # ジョブ用ネットワークのホスト側 (NAT、サービス用アドレス 10.201.0.1)
    gh-runner-netns = {
      description = "Host-side network for GitHub runner jobs (NAT, service address 10.201.0.1)";
      after = [
        "network-online.target"
        "firewall.service"
      ];
      wants = [ "network-online.target" ];
      before = [
        "docker.service"
        "gh-runner-dispatcher.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = tools;
      unitConfig.ConditionPathExists = "/opt/gh-runner/netns-up.sh";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/opt/gh-runner/netns-up.sh";
      };
    };

    gh-runner-host = {
      description = "Prepare host paths for GitHub runner slots";
      after = [ "local-fs.target" ];
      before = [ "gh-runner-dispatcher.service" ];
      wantedBy = [ "multi-user.target" ];
      path = tools;
      unitConfig.ConditionPathExists = "/var/lib/gh-runner/base-cli";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # 作業ディレクトリは短いパス /w/<id> (Unix ソケット 107 文字制限対策)
        mountpoint -q /w || mount --bind /var/lib/gh-runner/work /w
        # container: ジョブ用に、現行ベースの runner をホストの同じパスへ見せる
        mkdir -p /opt/actions-runner
        mountpoint -q /opt/actions-runner || mount --bind -o ro "$(readlink -f /var/lib/gh-runner/base-cli)/opt/actions-runner" /opt/actions-runner
        # 共有キャッシュの各ディレクトリを用意 (ツールが存在を前提にすることがある)
        # ジョブは runner (uid 1001) で書き込む
        grep -o "=/var/lib/gh-runner/cache/[^ ]*" /etc/gh-runner/cache.env | cut -c2- | xargs sh -c 'mkdir -p "$@" && chown 1001:1001 "$@"' _
        # 前回の異常終了で残った作業領域を掃除
        systemctl list-units "gh-job-*" --no-legend | grep -q . && exit 0
        for d in /var/lib/gh-runner/slots/*; do
          [ -d "$d" ] || continue
          mountpoint -q "$d/root" && umount -l "$d/root"
          rm -rf "$d"
        done
        rm -rf /var/lib/gh-runner/work/*
      '';
    };

    ghtkn-agent = {
      description = "ghtkn agent";
      wantedBy = [ "multi-user.target" ];
      environment = {
        inherit (ghtknEnv) HOME GHTKN_AGENT_SOCKET;
      };
      serviceConfig = {
        ExecStart = "${pkgs.ghtkn}/bin/ghtkn agent start";
        Restart = "on-failure";
      };
    };

    gh-runner-dispatcher = {
      description = "GitHub runner on-demand dispatcher (all repos)";
      after = [
        "network-online.target"
        "ghtkn-agent.service"
        "gh-runner-host.service"
        "gh-runner-netns.service"
      ];
      wants = [
        "network-online.target"
        "ghtkn-agent.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = tools;
      environment = ghtknEnv;
      unitConfig.ConditionPathExists = "/opt/gh-runner/dispatcher.py";
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -u /opt/gh-runner/dispatcher.py";
        Restart = "always";
        RestartSec = 5;
      };
    };

    # iac-aws main を slot-test ゲート付きで反映 (trunk based)
    gh-runner-sync = {
      description = "Apply iac-aws main to the GitHub runner host (gated by slot-test)";
      after = [
        "network-online.target"
        "ghtkn-agent.service"
      ];
      wants = [ "network-online.target" ];
      path = tools;
      environment = ghtknEnv;
      unitConfig.ConditionPathExists = "/opt/gh-runner/sync.sh";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/opt/gh-runner/sync.sh";
      };
    };

    gh-runner-update = {
      description = "Rebuild GitHub runner base rootfs";
      path = tools;
      environment = ghtknEnv;
      unitConfig.ConditionPathExists = "/opt/gh-runner/update.sh";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/opt/gh-runner/update.sh";
      };
    };
  };

  systemd.timers = {
    gh-runner-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "10min";
      };
    };
    gh-runner-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 04:00";
        Persistent = true;
      };
    };
  };
}
