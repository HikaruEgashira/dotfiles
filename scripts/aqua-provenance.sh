#!/usr/bin/env bash
# aqua-checksums.json の pin が上流の署名・来歴・checksum に裏付けられた artifact を指すことを検証する。
# 検証できない pin は provenance-ledger.tsv に受容理由を記録し、どちらにも無い pin は失敗させる。
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

# 上流 release の checksum file に pin と同じ sha256 が同じ asset 名で載っていることを確かめる。
# checksum_asset の %s は asset 名に置き換える (asset ごとに .sha256 を配る上流向け)。
verify_release() {
  local repo=$1 tag=$2 checksum_asset=$3 id asset name sums pinned n=0
  while IFS= read -r id; do
    asset=${id##*/}
    name=${checksum_asset//%s/$asset}
    sums=$work/${repo//\//_}_$name
    [ -s "$sums" ] || curl -fsSL --retry 3 \
      "https://github.com/$repo/releases/download/$tag/$name" -o "$sums"
    pinned=$(pinned_sha256 "$id")
    awk -v sum="$pinned" -v asset="$asset" '
      { f = $NF; sub(/^\*/, "", f) }
      tolower($1) == sum && (NF == 1 || f == asset) { found = 1 }
      END { exit !found }' "$sums" || {
      echo "error: $id の pin が $repo $tag の checksum と一致しない" >&2
      return 1
    }
    n=$((n + 1))
  done < <(jq -r --arg p "github_release/github.com/$repo/$tag/" \
    '.checksums[].id | select(startswith($p) and (ltrimstr($p) | contains("/") | not))' \
    "$aqua/aqua-checksums.json")
  [ "$n" -gt 0 ] || { echo "error: $repo $tag の pin が無い" >&2; return 1; }
  echo "ok: $repo $tag ($n assets, checksum)"
}

# 全 pin が検証対象か ledger のどちらかに載っていることを確かめる
verified=(openai/codex anomalyco/opencode)
release() {
  verify_release "$1" "$(version_of "$1")" "$2"
  verified+=("$1")
}

release googleworkspace/cli '%s.sha256'
release higgsfield-ai/cli checksums.txt
release sisaku-security/sisakulint "sisakulint_$(version_of sisaku-security/sisakulint | sed 's/^v//')_checksums.txt"
release pingdotgg/t3code SHA256SUMS
release sisaku-security/gh-intel checksums.txt

ledgered=$(grep -v '^#' "$aqua/provenance-ledger.tsv" | cut -f1)
status=0
while IFS= read -r pkg; do
  if printf '%s\n' "${verified[@]}" | grep -qxF "$pkg"; then
    if grep -qxF "$pkg" <<<"$ledgered"; then
      echo "error: $pkg は検証済みなので ledger から外す" >&2
      status=1
    fi
  elif grep -qxF "$pkg" <<<"$ledgered"; then
    echo "accepted: $pkg (来歴なし受容, provenance-ledger.tsv)"
  else
    echo "error: $pkg は検証も ledger 記録も無い" >&2
    status=1
  fi
done < <(sed -nE 's|^  - name: ([^@]+)@.+$|\1|p' "$aqua/aqua.yaml")
while IFS= read -r pkg; do
  [ -z "$pkg" ] || [ -n "$(version_of "$pkg")" ] || {
    echo "error: ledger の $pkg は aqua.yaml に無い" >&2
    status=1
  }
done <<<"$ledgered"
[ "$status" -eq 0 ]

# aqua.yaml の checksum.supported_envs と対応させる (npm の platform 表記)
platforms=(darwin-arm64 linux-x64)

codex=$(version_of openai/codex)
opencode=$(version_of anomalyco/opencode)

for platform in "${platforms[@]}"; do
  verify_npm @openai/codex "$codex-$platform" openai/codex rust-release.yml "codex-$codex-$platform.tgz"
  verify_npm "@opencode/cli-$platform" "$opencode" anomalyco/opencode release.yml "cli-$platform-$opencode.tgz"
done
