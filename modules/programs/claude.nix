{ lib, pkgs, ... }:
let
  managed = [
    "CLAUDE.md"
    "statusline-command.sh"
    "hooks/bash_command_validator.py"
    "hooks/say_on_stop.py"
    "bin/claude-caffeinate.sh"
  ];

  executableFiles = {
    "statusline-command.sh" = true;
    "hooks/bash_command_validator.py" = true;
    "hooks/say_on_stop.py" = true;
    "bin/claude-caffeinate.sh" = true;
  };
in
{
  home.file = lib.listToAttrs (
    map (rel: {
      name = ".claude/${rel}";
      value = {
        source = ./claude/${rel};
        executable = executableFiles.${rel} or false;
      };
    }) managed
  );

  # Existing non-symlink files block activation; rename them out of the way once.
  home.activation.preNixClaudeBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for rel in ${lib.escapeShellArgs managed}; do
      target="$HOME/.claude/$rel"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$target" "$target.pre-nix"
      fi
    done
  '';
}
