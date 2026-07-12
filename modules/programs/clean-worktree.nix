{
  config,
  pkgs,
  lib,
  ...
}:

let
  runner = pkgs.writeShellScript "clean-worktree" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.git
        pkgs.gh
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.findutils
      ]
    }:$PATH
    exec "$HOME/dotfiles/scripts/clean-worktree.sh"
  '';
in
{
  launchd.agents.clean-worktree = {
    enable = true;
    config = {
      Label = "dev.egahika.clean-worktree";
      ProgramArguments = [ "${runner}" ];
      StartCalendarInterval = [
        {
          Weekday = 1;
          Hour = 9;
          Minute = 30;
        }
      ];
      RunAtLoad = false;
      StandardOutPath = "${config.home.homeDirectory}/.cache/clean-worktree.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/clean-worktree.err";
    };
  };
}
