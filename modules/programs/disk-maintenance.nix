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
      StartCalendarInterval = [
        {
          Weekday = 1;
          Hour = 10;
          Minute = 0;
        }
      ];
      RunAtLoad = false;
      EnvironmentVariables = {
        PATH =
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.findutils
            pkgs.gawk
          ]
          + ":/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.cache/disk-maintenance.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/disk-maintenance.err";
    };
  };
}
