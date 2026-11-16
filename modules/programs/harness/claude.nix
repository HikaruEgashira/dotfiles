{
  config,
  pkgs,
  lib,
  ...
}:

(import ../../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Claude" [
  {
    rel = ".claude/CLAUDE.md";
    source = ./AGENTS.md;
  }
  {
    rel = ".claude/bin/claude-caffeinate.sh";
    source = ./claude/bin/claude-caffeinate.sh;
    executable = true;
  }
]
// {
  home.sessionVariables.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";

  # GUI から起動される claude (T3 Code / desktop app) はシェルの環境変数を継承しないため launchd domain に流す
  launchd.agents.claude-env = {
    enable = true;
    config = {
      Label = "com.claude.env";
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "CLAUDE_CODE_EXPERIMENTAL_CODE_MODE"
        "1"
      ];
      RunAtLoad = true;
    };
  };

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
