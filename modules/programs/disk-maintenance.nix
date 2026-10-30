{
  config,
  lib,
  pkgs,
  ...
}:

{
  launchd.agents.disk-maintenance = {
    enable = true;
    config = {
      Label = "dev.egahika.disk-maintenance";
      ProgramArguments = [ "${config.home.homeDirectory}/dotfiles/scripts/disk-maintenance.sh" ];
      # 週次だと一日で数 GB 増える使い方に追いつかない。空き率で発火を抑えるので 6h 毎に見る
      StartInterval = 6 * 60 * 60;
      RunAtLoad = true;
      EnvironmentVariables = {
        PATH =
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.findutils
            pkgs.gawk
            pkgs.gh
            pkgs.git
            pkgs.podman
            pkgs.python3
          ]
          + ":/opt/homebrew/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.cache/disk-maintenance.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/disk-maintenance.err";
    };
  };
}
