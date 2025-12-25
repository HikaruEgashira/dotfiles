{ pkgs, ... }:

{
  home.packages = [
    pkgs.cachix
    pkgs.pinentry-curses
    pkgs.lato
    pkgs.mise
    pkgs.devenv
    pkgs.ghq
    pkgs.gh
    pkgs.ripgrep
    pkgs.fd
  ];
}
