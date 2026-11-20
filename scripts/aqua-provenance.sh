#!/usr/bin/env bash
# registry.yaml に checksum asset がある github_release package は上流 checksum と pin を照合し、それ以外は provenance-ledger.tsv に記録する (scripts/aqua-coverage.sh)。
# aqua-checksums.json の pin が上流の署名・来歴に裏付けられた artifact を指すことを検証する。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
aqua=$root/modules/programs/aqua
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

version_of() {
  sed -nE "s|^  - name: $1@(.+)\$|\\1|p" "$aqua/aqua.yaml"
}

pinned_sha256() {
  jq -er --arg id "$1" '.checksums[] | select(.id == $id) | .checksum | ascii_downcase' \
    "$aqua/aqua-checksums.json"
}

verify_npm() {
  local pkg=$1 version=$2 repo=$3 workflow=$4 tarball=$5 file
  file=$work/${tarball##*/}
  curl -fsSL --retry 3 "https://registry.npmjs.org/$pkg/-/$tarball" -o "$file"
  curl -fsSL --retry 3 "https://registry.npmjs.org/-/npm/v1/attestations/${pkg/\//%2f}@$version" |
    jq -e '.attestations[] | select(.predicateType == "https://slsa.dev/provenance/v1") | .bundle' \
      >"$file.bundle.json"
  gh attestation verify "$file" --bundle "$file.bundle.json" --digest-alg sha512 \
    --repo "$repo" --signer-workflow "$repo/.github/workflows/$workflow" >/dev/null
  [ "$(sha256sum "$file" | cut -d' ' -f1)" = "$(pinned_sha256 "http/registry.npmjs.org/$pkg/-/$tarball")" ]
  echo "ok: $pkg $version ($repo $workflow)"
}

# aqua.yaml の checksum.supported_envs と対応させる (npm の platform 表記)
platforms=(darwin-arm64 linux-x64)

codex=$(version_of openai/codex)
opencode=$(version_of anomalyco/opencode)

for platform in "${platforms[@]}"; do
  verify_npm @openai/codex "$codex-$platform" openai/codex rust-release.yml "codex-$codex-$platform.tgz"
  verify_npm "@opencode/cli-$platform" "$opencode" anomalyco/opencode release.yml "cli-$platform-$opencode.tgz"
done

verify_checksum_asset() {
  local owner=$1 repo=$2 template=$3 id version asset name sums upstream
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    asset=${id##*/}
    version=${id#"github_release/github.com/$owner/$repo/"}
    version=${version%/"$asset"}
    name=${template//'{{.Asset}}'/$asset}
    name=${name//'{{trimV .Version}}'/${version#v}}
    name=${name//'{{.Version}}'/$version}
    sums=$work/$owner-$repo-${name//\//_}
    if [ ! -f "$sums" ]; then
      curl -fsSL --retry 3 "https://github.com/$owner/$repo/releases/download/$version/$name" -o "$sums" ||
        { echo "error: fetch $owner/$repo $version $name" >&2; exit 1; }
    fi
    upstream=$(awk -v a="$asset" '$2 == a || $2 == "*" a || NF == 1 { print tolower($1); exit }' "$sums")
    if [ "$upstream" != "$(pinned_sha256 "$id")" ]; then
      echo "error: $id pin does not match upstream $name" >&2
      exit 1
    fi
    echo "ok: $owner/$repo $version $asset ($name)"
  done < <(jq -r --arg p "github_release/github.com/$owner/$repo/" \
    '.checksums[].id | select(startswith($p))' "$aqua/aqua-checksums.json")
}

while read -r owner repo template; do
  verify_checksum_asset "$owner" "$repo" "$template"
done < <(yq -r '.packages[] | select(.checksum) | .repo_owner + " " + .repo_name + " " + .checksum.asset' "$aqua/registry.yaml")
