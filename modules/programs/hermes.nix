{ lib, ... }:
let
  managed = [
    "SOUL.md"
    "config.yaml"
  ];
in
{
  home.file = lib.listToAttrs (
    map (rel: {
      name = ".hermes/${rel}";
      value = {
        source = ./hermes/${rel};
        force = true;
      };
    }) managed
  );
}
