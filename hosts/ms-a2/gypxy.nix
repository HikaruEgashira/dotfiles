# gypxy hub の公開面。プロセス本体は home-manager の user service (modules/programs/gypxy.nix)
{ config, lib, ... }:
{
  # user service をログインなしで起動しておく
  users.users.hikae.linger = true;

  systemd.services.gypxy-serve = {
    description = "Expose gypxy on the tailnet over HTTPS";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=443 http://127.0.0.1:9300";
      Restart = "on-failure";
      RestartSec = 30;
    };
  };
}
