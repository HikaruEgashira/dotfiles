#!/usr/bin/env bash
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

render_checksum_asset() {
  local template=$1 asset=$2 version=$3 semver=$4 out
  out=${template//'{{.Asset}}'/$asset}
  out=${out//'{{trimV .Version}}'/${version#v}}
  out=${out//'{{.Version}}'/$version}
  out=${out//'{{trimV .SemVer}}'/${semver#v}}
  out=${out//'{{.SemVer}}'/$semver}
  case $out in *'{{'*) echo "unsupported checksum asset template: $template" >&2; return 1 ;; esac
  printf '%s\n' "$out"
}

verify_github_checksum() {
  local owner=$1 repo=$2 template=$3 prefix=$4 version id asset sums file expected n=0
  version=$(version_of "$owner/$repo")
  [ -n "$version" ]
  while IFS= read -r id; do
    asset=${id#"github_release/github.com/$owner/$repo/$version/"}
    sums=$(render_checksum_asset "$template" "$asset" "$version" "${version#"$prefix"}")
    file=$work/$owner-$repo-${sums//\//_}
    [ -f "$file" ] || curl -fsSL --retry 3 "https://github.com/$owner/$repo/releases/download/$version/$sums" -o "$file"
    expected=$(awk -v a="$asset" '{ f = $2; sub(/^[*]/, "", f); sub(/^[.]\//, "", f) } f == a || (NF == 1 && NR == 1) { print tolower($1); exit }' "$file")
    if [ "$expected" != "$(pinned_sha256 "$id")" ]; then
      echo "FAIL: $id does not match upstream $sums" >&2
      return 1
    fi
    n=$((n + 1))
  done < <(jq -r --arg p "github_release/github.com/$owner/$repo/$version/" \
    '.checksums[].id | select(startswith($p))' "$aqua/aqua-checksums.json")
  [ "$n" -gt 0 ]
  echo "ok: $owner/$repo $version ($n assets match upstream $template)"
}

# registry.yaml に checksum asset が定義された package だけを upstream と突き合わせる
while IFS=$'\t' read -r owner repo template prefix; do
  verify_github_checksum "$owner" "$repo" "$template" "$prefix"
done < <(yq -r '.packages[] | select(.type == "github_release" and .checksum.type == "github_release" and .checksum.asset) | [.repo_owner, .repo_name, .checksum.asset, (.version_prefix // "")] | @tsv' "$aqua/registry.yaml")

# aqua.yaml の checksum.supported_envs と対応させる (npm の platform 表記)
platforms=(darwin-arm64 linux-x64)

codex=$(version_of openai/codex)
opencode=$(version_of anomalyco/opencode)

for platform in "${platforms[@]}"; do
  verify_npm @openai/codex "$codex-$platform" openai/codex rust-release.yml "codex-$codex-$platform.tgz"
  verify_npm "@opencode/cli-$platform" "$opencode" anomalyco/opencode release.yml "cli-$platform-$opencode.tgz"
done
