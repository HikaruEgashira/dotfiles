{ pkgs, ... }:

let
  cica = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "cica";
    version = "5.0.3";

    src = pkgs.fetchzip {
      url = "https://github.com/miiton/Cica/releases/download/v${version}/Cica_v${version}.zip";
      hash = "sha256-BtDnfWCfD9NE8tcWSmk8ciiInsspNPTPmAdGzpg62SM=";
      stripRoot = false;
    };

    installPhase = ''
      runHook preInstall
      install -Dm644 *.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';
  };
in
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    cica
  ];
}
