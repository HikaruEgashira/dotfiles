# NixOS-WSL のシステム層。旧 /etc/nixos/configuration.nix の手書き設定を再現する
{ pkgs, ... }:
{
  wsl = {
    enable = true;
    defaultUser = "hikae";
  };

  networking.hostName = "wsl";

  users.users.hikae = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # WSL セッション外でも ssh-agent / ghtkn-agent の systemd user service を常駐させる
    linger = true;
  };

  security.sudo.wheelNeedsPassword = false;

  # upstream binary (Aqua 管理の CLI 等) を FHS loader なしで動かす
  programs.nix-ld.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "hikae"
    ];
  };

  environment.systemPackages = [ pkgs.git ];

  system.stateVersion = "25.05";
}
