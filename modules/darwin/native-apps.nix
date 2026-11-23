{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.dotfiles = {
    tailscaleGui = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the signed Tailscale GUI pkg. Disable when the host runs the OSS tailscaled.";
    };
    secretive = lib.mkEnableOption "the signed Secretive app that holds the Touch ID gated sudo key in the Secure Enclave";
  };

  config.system.activationScripts.postActivation.text = lib.mkAfter ''
    PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
      ]
    }:/usr/bin:/usr/sbin:/bin" MAS=${pkgs.mas}/bin/mas SECRETIVE=${
      if config.dotfiles.secretive then "1" else "0"
    } TAILSCALE_GUI=${
      if config.dotfiles.tailscaleGui then "1" else "0"
    } ${pkgs.bash}/bin/bash ${./native-apps/install-system-apps.sh}
  '';
}
