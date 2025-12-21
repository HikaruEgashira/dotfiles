{ pkgs, ... }:

{
  home.packages = [
    # Utilities
    pkgs.cachix
    pkgs.pinentry-curses
    pkgs.lato

    # Development tools
    pkgs.mise
    pkgs.devenv
    pkgs.ghq
    pkgs.gh
    pkgs.ripgrep
    pkgs.fd
  ];
}
