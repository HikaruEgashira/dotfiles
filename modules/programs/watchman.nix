{ config, pkgs, ... }:

# Metro/Expo (pleno-live) spawns `watchman` and talks to a daemon bound to a
# fixed sockname. The agent is declared here; the old brew-installed plist had a
# hardcoded stale PATH (mise versions from months ago) and no triggers to use it.
let
  stateDir = "${config.home.homeDirectory}/.local/state/watchman/hikae-state";
in
{
  launchd.agents.watchman = {
    enable = true;
    config = {
      Label = "com.github.facebook.watchman";
      ProgramArguments = [
        "${pkgs.watchman}/bin/watchman"
        "--foreground"
        "--logfile=${stateDir}/log"
        "--log-level=1"
        "--sockname=${stateDir}/sock"
        "--statefile=${stateDir}/state"
        "--pidfile=${stateDir}/pid"
      ];
      RunAtLoad = true;
      KeepAlive.Crashed = true;
      Nice = -5;
      ProcessType = "Interactive";
    };
  };
}
