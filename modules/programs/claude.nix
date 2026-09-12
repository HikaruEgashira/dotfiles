{ lib, pkgs, ... }:
let
  managed = [
    "CLAUDE.md"
    "bin/claude-caffeinate.sh"
  ];
in
{
  home.file = lib.listToAttrs (
    map (rel: {
      name = ".claude/${rel}";
      value = {
        source = ./claude/${rel};
        executable = lib.hasPrefix "bin/" rel;
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
