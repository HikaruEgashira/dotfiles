#!/usr/bin/env bash
# hub が起動時に private の release を取りに行かず、aqua の pin と checksum で固定した store の gypxy を実行することを確かめる。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hm=".#nixosConfigurations.ms-a2.config.home-manager.users.hikae"
cd "$root"

pin=$(sed -nE 's|^  - name: gh-intel/gh-intel@gypxy/(v[0-9.]+)$|\1|p' modules/programs/aqua/aqua.yaml)
want=$(grep -A1 "\"github_release/github.com/gh-intel/gh-intel/gypxy/$pin/gypxy_${pin}_linux_amd64.tar.gz\"" \
  modules/programs/aqua/aqua-checksums.json | sed -nE 's/.*"checksum": "([0-9A-F]+)".*/\1/p' | tr 'A-F' 'a-f')
[ -n "$pin" ] && [ -n "$want" ] || {
  echo "FAIL: gypxy pin or checksum not found" >&2
  exit 1
}

version=$(nix eval --raw "$hm.programs.gypxy.package.version")
hash=$(nix eval --raw "$hm.programs.gypxy.package.src.outputHash")
expect=$(nix hash convert --hash-algo sha256 --to base16 "$hash")
[ "$version" = "$pin" ] || {
  echo "FAIL: package version $version != aqua pin $pin" >&2
  exit 1
}
[ "$expect" = "$want" ] || {
  echo "FAIL: fetchurl hash $expect != aqua checksum $want" >&2
  exit 1
}

pkg=$(nix eval --raw "$hm.programs.gypxy.package.outPath")
run=$(nix eval --raw "$hm.systemd.user.services.gypxy.Service.ExecStart" --apply builtins.head)
text=$(nix derivation show "$run" | sed -n 's/.*"text": *"\(.*\)".*/\1/p')
case "$text" in
*aquaproj* | *AQUA_*)
  echo "FAIL: hub ExecStart still runs gypxy through aqua" >&2
  exit 1
  ;;
esac
case "$text" in
*"exec $pkg/bin/gypxy "*) ;;
*)
  echo "FAIL: hub ExecStart does not exec $pkg/bin/gypxy" >&2
  exit 1
  ;;
esac
case "$text" in
*"-config /nix/store/"*"-gypxy-checked.json"*) ;;
*)
  echo "FAIL: hub config is not validated by the pinned gypxy -check at build time" >&2
  exit 1
  ;;
esac
echo "ok: hub runs $pkg/bin/gypxy (gypxy $version, $hash)"
