{
  config,
  pkgs,
  lib,
  ...
}:

(import ../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Claude" [
  {
    rel = ".claude/CLAUDE.md";
    source = ./claude/CLAUDE.md;
  }
  {
    rel = ".claude/bin/claude-caffeinate.sh";
    source = ./claude/bin/claude-caffeinate.sh;
    executable = true;
  }
]
// {
  launchd.agents.claude-caffeinate = {
    enable = true;
    config = {
      Label = "com.claude.caffeinate";
      ProgramArguments = [ "${config.home.homeDirectory}/.claude/bin/claude-caffeinate.sh" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/.claude/logs/caffeinate.log";
      StandardErrorPath = "${config.home.homeDirectory}/.claude/logs/caffeinate.log";
    };
  };
}
