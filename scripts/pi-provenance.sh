#!/usr/bin/env bash
# pi-extensions.json の固定版 npm extension が上流 workflow の SLSA provenance を持つことを検証する。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pins=$root/modules/programs/harness/pi-extensions.json
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

jq -r '.[] | [.name, .version, .repo, .workflow] | @tsv' "$pins" |
  while IFS=$'\t' read -r pkg version repo workflow; do
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
      echo "not an exact version: $pkg@$version" >&2
      exit 1
    }
    tarball=$(curl -fsSL --retry 3 "https://registry.npmjs.org/${pkg/\//%2f}/$version" | jq -er .dist.tarball)
    file=$work/${tarball##*/}
    curl -fsSL --retry 3 "$tarball" -o "$file"
    curl -fsSL --retry 3 "https://registry.npmjs.org/-/npm/v1/attestations/${pkg/\//%2f}@$version" |
      jq -e '.attestations[] | select(.predicateType == "https://slsa.dev/provenance/v1") | .bundle' \
        >"$file.bundle.json"
    gh attestation verify "$file" --bundle "$file.bundle.json" --digest-alg sha512 \
      --repo "$repo" --signer-workflow "$repo/.github/workflows/$workflow" >/dev/null
    echo "ok: $pkg $version ($repo $workflow)"
  done
