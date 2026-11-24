{
  config,
  pkgs,
  lib,
  ...
}:

(import ../../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Claude" (
  [
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
  ++
    map
      (f: {
        rel = ".claude/skills/pleno-theme/${f}";
        source = ./claude/mods/pleno-theme + "/${f}";
      })
      [
        ".claude-plugin/plugin.json"
        "hooks/hooks.json"
        "hooks/register.ts"
        "hooks/make-colors.js"
        "hooks/make-colors.d.ts"
      ]
)
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
