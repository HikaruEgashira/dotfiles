{
  config,
  pkgs,
  lib,
  ...
}:

{
  launchd.agents.clean-worktree = {
    enable = true;
    config = {
      Label = "dev.egahika.clean-worktree";
      ProgramArguments = [ "${config.home.homeDirectory}/dotfiles/scripts/clean-worktree.sh" ];
      StartCalendarInterval = [
        {
          Weekday = 1;
          Hour = 9;
          Minute = 30;
        }
      ];
      RunAtLoad = false;
      EnvironmentVariables = {
        PATH =
          lib.makeBinPath [
            pkgs.git
            pkgs.gh
            pkgs.coreutils
            pkgs.gnugrep
          ]
          + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.cache/clean-worktree.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/clean-worktree.err";
    };
  };
}
