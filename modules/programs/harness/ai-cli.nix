{ lib, pkgs, ... }:

{
  home.activation.installAiCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${
      lib.makeBinPath [
        pkgs.bash
        pkgs.curl
      ]
    }:$PATH" run ${pkgs.bash}/bin/bash ${./ai-cli-install.sh}
  '';
}
