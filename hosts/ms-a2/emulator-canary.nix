# github-emulator canary の origin。公開は emulator.canary.gh-intel.com
# (sisaku-security/gh-intel.com emulator.tf: Cloudflare Access + proxy Worker)。
# - deploy: gypxy hub の mirror (main への push は hub 経由なので最新) から main を 5 分おきに取り込み、
#   変化があればビルドして再起動する (trunk based)。GitHub の認証情報は持たない
# - funnel: Worker が届くよう :8443 を Tailscale Funnel で公開する。emulator 自身が Access JWT を検証するため
#   Funnel を直接叩いても Access を迂回できない。aud が未設定なら emulator も funnel も起動しない
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # gh-intel.com の `terraform output emulator_access` (非秘密の識別子)
  accessAud = "dfc4d6781c73acc551cc73b6de32bca0fefec7cbac34a3b92a76e87dce30d10a";
  teamDomain = "https://gh-intel.cloudflareaccess.com";
  port = 9299;
  stateDir = "/var/lib/emulator-canary";
  mirror = "/home/hikae/.local/state/gypxy/git/sisaku-security/github-emulator.git";
  enabled = accessAud != "";

  deploy = pkgs.writeShellScript "emulator-canary-deploy" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.git
        pkgs.coreutils
        config.nix.package
      ]
    }:$PATH
    src=${stateDir}/src
    [ -d $src/.git ] || git clone -q --no-checkout ${mirror} $src
    git -C $src fetch -q origin main
    rev=$(git -C $src rev-parse FETCH_HEAD)
    [ "$rev" = "$(cat ${stateDir}/deployed 2>/dev/null)" ] && exit 0
    git -C $src -c advice.detachedHead=false checkout -q --force "$rev"
    cd $src
    nix develop $src --command sh -c 'cargo run -q -p xtask -- fetch-spec && cargo build -q --release -p github-emulator-router'
    install -m 0755 target/release/github-emulator ${stateDir}/github-emulator.new
    mv ${stateDir}/github-emulator.new ${stateDir}/github-emulator
    echo "$rev" >${stateDir}/deployed
    echo "deployed $rev"
  '';

  run = pkgs.writeShellScript "emulator-canary-run" ''
    set -eu
    umask 077
    [ -s ${stateDir}/admin-token ] || ${pkgs.openssl}/bin/openssl rand -hex 32 >${stateDir}/admin-token
    export EMULATOR_ADMIN_TOKEN=$(cat ${stateDir}/admin-token)
    export PATH=${lib.makeBinPath [ pkgs.git ]}:$PATH
    exec ${stateDir}/github-emulator --host 127.0.0.1 -p ${toString port} \
      --base-url https://emulator.canary.gh-intel.com --data-dir ${stateDir}/data
  '';
in
lib.mkIf enabled {
  systemd = {
    tmpfiles.rules = [ "d ${stateDir} 0750 hikae users -" ];

    timers.emulator-canary-deploy = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitInactiveSec = "5m";
      };
    };

    # 新しいバイナリが置かれたら再起動する
    paths.emulator-canary-restart = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = "${stateDir}/deployed";
    };

    services = {
      emulator-canary-deploy = {
        description = "Build github-emulator main from the gypxy mirror";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "hikae";
          Environment = "HOME=/home/hikae";
          ExecStart = deploy;
          Nice = 10;
        };
      };

      emulator-canary-restart.serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart emulator-canary.service";
      };

      emulator-canary = {
        description = "github-emulator canary (emulator.canary.gh-intel.com origin)";
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = "${stateDir}/github-emulator";
        environment = {
          EMULATOR_ACCESS_TEAM_DOMAIN = teamDomain;
          EMULATOR_ACCESS_AUD = accessAud;
        };
        serviceConfig = {
          User = "hikae";
          ExecStart = run;
          Restart = "always";
          RestartSec = 5;
        };
      };

      emulator-canary-funnel = {
        description = "Expose the github-emulator canary to the Cloudflare Worker over Tailscale Funnel";
        after = [
          "tailscaled.service"
          "emulator-canary.service"
        ];
        requires = [ "emulator-canary.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe config.services.tailscale.package} funnel --bg --https=8443 http://127.0.0.1:${toString port}";
          ExecStop = "${lib.getExe config.services.tailscale.package} funnel --https=8443 off";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };
    };
  };
}
