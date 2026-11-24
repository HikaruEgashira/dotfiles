{
  config,
  pkgs,
  lib,
  ...
}:

(import ../../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Claude" ([
  {
    rel = ".claude/CLAUDE.md";
    source = ./AGENTS.md;
  }
  {
    rel = ".claude/bin/claude-caffeinate.sh";
    source = ./claude/bin/claude-caffeinate.sh;
    executable = true;
  }
])
// {
  # The plugin loader rejects files that resolve outside the plugin dir, so store symlinks cannot be used.
  home.activation.claudePlenoTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.claude/skills/pleno-theme"
    $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -r --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r --exclude=.claude-plugin/types ${./claude/mods/pleno-theme}/ "$dest/"
  '';

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
