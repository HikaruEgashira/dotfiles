# gypxy hub の実行ファイル。版は aqua.yaml の pin、hash は aqua-checksums.json (cosign 署名付き checksums.txt と一致を確かめた値) から読む。
# release は private のため nix は取れない。scripts/gypxy-seed.sh が署名を検証した asset を store に入れておく。
# store に無ければ build が失敗し、activation は前の generation の hub を動かし続ける。
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  aquaDir = ./aqua;
  version = lib.pipe (builtins.readFile "${aquaDir}/aqua.yaml") [
    (lib.splitString "\n")
    (map (builtins.match "  - name: sisaku-security/gh-intel@gypxy/(v[0-9.]+)"))
    (lib.findFirst (m: m != null) (throw "gypxy pin is missing in aqua.yaml"))
    builtins.head
  ];
  platform = stdenvNoCC.hostPlatform;
  os = if platform.isDarwin then "darwin" else "linux";
  arch = if platform.isAarch64 then "arm64" else "amd64";
  stem = "gypxy_${version}_${os}_${arch}";
  id = "github_release/github.com/sisaku-security/gh-intel/gypxy/${version}/${stem}.tar.gz";
  entry =
    lib.findFirst (c: c.id == id) (throw "${id} is missing in aqua-checksums.json")
      (builtins.fromJSON (builtins.readFile "${aquaDir}/aqua-checksums.json")).checksums;
in
stdenvNoCC.mkDerivation {
  pname = "gypxy";
  inherit version;
  src = fetchurl {
    url = "https://github.com/sisaku-security/gh-intel/releases/download/gypxy/${version}/${stem}.tar.gz";
    sha256 = lib.toLower entry.checksum;
  };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    install -Dm0755 gypxy $out/bin/gypxy
  '';
  meta.mainProgram = "gypxy";
}
