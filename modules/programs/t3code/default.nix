{ lib, ... }:
{
  # T3 Code opens theme files with O_NOFOLLOW, so store symlinks from home.file are skipped
  home.activation.t3codeThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /usr/bin/install -d -m 755 "$HOME/.t3/userdata/themes"
    $DRY_RUN_CMD /usr/bin/install -m 644 ${./themes}/*.json "$HOME/.t3/userdata/themes/"
  '';
}
