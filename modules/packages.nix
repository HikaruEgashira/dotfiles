{
  pkgs,
  lib,
  dotfilesPath,
  ...
}:

let
  ledger = import "${dotfilesPath}/lib/ledger.nix" { inherit lib; };
  registry = import "${dotfilesPath}/lib/package-registry.nix" { inherit pkgs lib; };
in
{
  home.packages = ledger.pkgsOf registry.all;
}
