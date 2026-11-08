#!/usr/bin/env bash
# aqua-checksums.json の pin が上流の署名・来歴に裏付けられた artifact を指すことを検証する。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
aqua=$root/modules/programs/aqua
claude_fpr=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
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

verify_claude() {
  local version=$1 base gnupg
  base=https://downloads.claude.ai/claude-code-releases/$version
  gnupg=$work/gnupg
  mkdir -m 700 "$gnupg"
  gpg --homedir "$gnupg" --batch --quiet --import "$aqua/keys/claude-code.asc"
  curl -fsSL --retry 3 "$base/manifest.json" -o "$work/manifest.json"
  curl -fsSL --retry 3 "$base/manifest.json.sig" -o "$work/manifest.json.sig"
  gpg --homedir "$gnupg" --batch --status-fd 1 --verify "$work/manifest.json.sig" "$work/manifest.json" 2>/dev/null |
    grep -q "^\[GNUPG:\] VALIDSIG $claude_fpr "
  jq -e --arg v "$version" '.version == $v' "$work/manifest.json" >/dev/null
  for platform in "${platforms[@]}"; do
    [ "$(jq -r --arg p "$platform" '.platforms[$p].checksum' "$work/manifest.json")" = \
      "$(pinned_sha256 "http/downloads.claude.ai/claude-code-releases/$version/$platform/claude")" ]
    echo "ok: claude-code $version $platform (GPG $claude_fpr)"
  done
}

# aqua.yaml の checksum.supported_envs と対応させる (npm / claude の platform 表記)
platforms=(darwin-arm64 linux-x64)

codex=$(version_of openai/codex)
opencode=$(version_of anomalyco/opencode)
claude=$(version_of anthropics/claude-code)

for platform in "${platforms[@]}"; do
  verify_npm @openai/codex "$codex-$platform" openai/codex rust-release.yml "codex-$codex-$platform.tgz"
  verify_npm "@opencode/cli-$platform" "$opencode" anomalyco/opencode release.yml "cli-$platform-$opencode.tgz"
done
verify_claude "$claude"
