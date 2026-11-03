{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.activation.installNativeApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="$HOME/.nix-profile/bin:${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
        pkgs.undmg
      ]
    }:/usr/bin:/bin" run ${pkgs.bash}/bin/bash ${./native-apps/install-user-apps.sh}
  '';
}
