{ lib, pkgs, ... }:
let
  managed = [
    "SOUL.md"
    "config.yaml"
  ];
in
{
  home.file = lib.listToAttrs (
    map (rel: {
      name = ".hermes/${rel}";
      value = {
        source = ./hermes/${rel};
        force = true;
      };
    }) managed
  );

  # `hermes setup`/`hermes config set` rewrite config.yaml; existing
  # non-symlink files would block activation. Rename them out of the way once.
  home.activation.preHermesBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for rel in ${lib.escapeShellArgs managed}; do
      target="$HOME/.hermes/$rel"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$target" "$target.pre-nix"
      fi
    done
  '';
}
