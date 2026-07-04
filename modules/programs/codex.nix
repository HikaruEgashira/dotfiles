{ lib, pkgs, ... }:
let
  managed = [ "AGENTS.md" ];
in
{
  home.file = lib.listToAttrs (
    map (rel: {
      name = ".codex/${rel}";
      value.source = ./claude/CLAUDE.md;
    }) managed
  );

  home.activation.preNixCodexBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for rel in ${lib.escapeShellArgs managed}; do
      target="$HOME/.codex/$rel"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$target" "$target.pre-nix"
      fi
    done
  '';
}
