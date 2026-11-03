{ lib, pkgs, ... }:

{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
      ]
    }:/usr/bin:/usr/sbin:/bin" MAS=${pkgs.mas}/bin/mas ${pkgs.bash}/bin/bash ${./native-apps/install-system-apps.sh}
  '';
}
