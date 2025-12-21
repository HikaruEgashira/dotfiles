{ pkgs, ... }:

{
  home.packages = [
    # Version managers
    pkgs.mise

    # Development tools
    pkgs.devenv
    pkgs.ghq
    pkgs.gh
    pkgs.ripgrep

    # Nix tools
    pkgs.cachix

    # GPG tools
    pkgs.pinentry-curses

    # Fonts
    pkgs.lato
  ];
}
