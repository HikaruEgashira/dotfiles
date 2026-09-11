{ lib, pkgs, ... }:
{
  # pi injects APPEND_SYSTEM.md into its built-in system prompt; AGENTS.md is context-only.
  home.file.".pi/agent/APPEND_SYSTEM.md".source = ./claude/CLAUDE.md;

  home.activation.preNixPiBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    file="$HOME/.pi/agent/APPEND_SYSTEM.md"
    if [ -e "$file" ] && [ ! -L "$file" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$file" "$file.pre-nix"
    fi
  '';
}
