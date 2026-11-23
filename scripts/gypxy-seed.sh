#!/usr/bin/env bash
# gypxy の release asset を cosign 署名と aqua-checksums.json の sha256 で検証し、hub の nix store に入れる。
# release は private で、hub の非対話の service と nix は取れないため、認証できる端末 (Mac) から渡す。
# usage: scripts/gypxy-seed.sh [ssh-host] [os_arch]   (既定: ms-a2 linux_amd64)
set -euo pipefail

host=${1:-ms-a2}
target=${2:-linux_amd64}
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
aqua=$root/modules/programs/aqua
repo=gh-intel/gh-intel

version=$(sed -nE 's|^  - name: gh-intel/gh-intel@gypxy/(v[0-9.]+)$|\1|p' "$aqua/aqua.yaml")
[ -n "$version" ] || {
  echo "gypxy pin is missing in aqua.yaml" >&2
  exit 1
}
tag=gypxy/$version
asset=gypxy_${version}_${target}.tar.gz
want=$(jq -er --arg id "github_release/github.com/$repo/$tag/$asset" \
  '.checksums[] | select(.id == $id) | .checksum | ascii_downcase' "$aqua/aqua-checksums.json")

cosign=(cosign)
command -v cosign >/dev/null || cosign=(nix run nixpkgs#cosign --)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
GH_HOST=github.com gh release download "$tag" --repo "$repo" --dir "$work" \
  --pattern "$asset" --pattern checksums.txt --pattern checksums.txt.sigstore.json

"${cosign[@]}" verify-blob --bundle "$work/checksums.txt.sigstore.json" \
  --certificate-identity "https://github.com/$repo/.github/workflows/gypxy-release.yml@refs/tags/$tag" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com "$work/checksums.txt"

signed=$(awk -v f="$asset" '$2 == f { print $1 }' "$work/checksums.txt")
got=$(shasum -a 256 "$work/$asset" | awk '{ print $1 }')
if [ "$signed" != "$want" ] || [ "$got" != "$want" ]; then
  echo "sha256 mismatch: aqua=$want signed=$signed file=$got" >&2
  exit 1
fi

# fetchurl と同じ名前と hash で入れるので、store path は nix が期待するものと一致する
scp -q "$work/$asset" "$host:/tmp/$asset"
# shellcheck disable=SC2029
ssh "$host" "nix-store --add-fixed sha256 /tmp/$asset && rm -f /tmp/$asset"
