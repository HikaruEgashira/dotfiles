{ lib, pkgs, ... }:
{
  imports = [ ./windows.nix ];

  home.homeDirectory = lib.mkForce "/home/hikae";

  # この端末で発行した署名鍵 (~/.ssh/id_ed25519_sign)。公開鍵は git.nix の allowedSigners にも載せる
  programs.git.signing.key = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMgH2JVbVWM1JEQXafU+Zqeb9Ta1/YBkjPvnUbi8+Ff";

  # macOS 専用 (`defaults`) なので WSL では何もしない
  home.activation.cmuxDefaults = lib.mkForce (lib.hm.dag.entryAnywhere ":");

  # /usr/bin/install は NixOS に無いので coreutils の install を使う
  home.activation.t3codeThemes = lib.mkForce (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 755 "$HOME/.t3/userdata/themes"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 ${../../modules/programs/t3code/themes}/*.json "$HOME/.t3/userdata/themes/"
    ''
  );
}
