# WSL と bare-metal NixOS で共有する Linux 用 home 差分
{ lib, pkgs, ... }:
{
  home = {
    homeDirectory = lib.mkForce "/home/hikae";

    activation = {
      # macOS 専用 (`defaults`) なので Linux では何もしない
      cmuxDefaults = lib.mkForce (lib.hm.dag.entryAnywhere ":");

      # /usr/bin/install は NixOS に無いので coreutils の install を使う
      t3codeThemes = lib.mkForce (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 755 "$HOME/.t3/userdata/themes"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 ${../../modules/programs/t3code/themes}/*.json "$HOME/.t3/userdata/themes/"
        ''
      );
    };
  };
}
