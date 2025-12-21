{ pkgs, ... }:

{
  home.packages = [
    # Version managers
    pkgs.mise

    # Development tools
    pkgs.ghq
    pkgs.gh
    pkgs.ripgrep

    # Nix tools
    pkgs.cachix

    # Fonts
    pkgs.lato
  ];
}
