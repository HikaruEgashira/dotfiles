{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.orca.serve;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  logFile = "${config.xdg.stateHome}/orca-serve.log";

  # 起動時の tailnet IP に bind し LAN へは晒さない。tailscaled 起動前は失敗させ supervisor に再試行させる
  run = pkgs.writeShellScript "orca-serve-run" ''
    set -eu
    ip=$(/run/current-system/sw/bin/tailscale ip -4 | ${pkgs.coreutils}/bin/head -n1)
    [ -n "$ip" ]
    exec ${cfg.bin} serve --port ${toString cfg.port} --bind "$ip" \
      --pairing-address ${cfg.pairingAddress} --refuse-public
  '';
in
{
  options.programs.orca.serve = {
    enable = lib.mkEnableOption "headless Orca runtime server on the tailnet";
    # Orca は nixpkgs に無く上流配布物を stateful に置く。宣言するのは起動条件だけ
    bin = lib.mkOption {
      type = lib.types.str;
      default =
        if isDarwin then
          "/Applications/Orca.app/Contents/Resources/bin/orca"
        else
          "${config.home.homeDirectory}/.local/bin/orca";
    };
    # 固定しないと 6768 が埋まった時に別 port へ逃げ、ペアリング済み client が繋がらなくなる
    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
    };
    pairingAddress = lib.mkOption { type = lib.types.str; };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf isDarwin {
        launchd.agents.orca-serve = {
          enable = true;
          config = {
            Label = "dev.egahika.orca-serve";
            ProgramArguments = [ "${run}" ];
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 30;
            StandardOutPath = logFile;
            StandardErrorPath = logFile;
          };
        };
      })
      (lib.mkIf (!isDarwin) {
        systemd.user.services.orca-serve = {
          Unit = {
            Description = "Orca runtime server (tailnet)";
            After = [ "network-online.target" ];
          };
          Service = {
            ExecStart = "${run}";
            # GUI セッションが無い host では Electron でなく Node runtime を使う
            Environment = [ "ORCA_SERVE_RUNTIME=orcad" ];
            Restart = "always";
            RestartSec = 30;
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
