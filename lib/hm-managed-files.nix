{ pkgs, lib }:

{
  # home.file entries made of repo files, with a one-time move-aside of a
  # regular file already occupying the target (blocks the store symlink).
  files =
    id: entries:
    let
      rels = map (e: e.rel) entries;
    in
    {
      home.file = lib.listToAttrs (
        map (e: {
          name = e.rel;
          value = {
            source = e.source;
          }
          // lib.optionalAttrs (e ? executable) { executable = e.executable; };
        }) entries
      );

      home.activation."preNix${id}Backup" = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        for rel in ${lib.escapeShellArgs rels}; do
          target="$HOME/$rel"
          if [ -e "$target" ] && [ ! -L "$target" ]; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$target" "$target.pre-nix"
          fi
        done
      '';
    };
}
