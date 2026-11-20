#!/usr/bin/env bash
# package-registry.nix の fetchurl pin が上流の署名に裏付けられた artifact を指すことを検証する。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
registry=$root/lib/package-registry.nix
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

field_of() {
  awk -v name="$1" -v key="$2" '
    $0 ~ "pname = \"" name "\";" { found = 1 }
    found && $0 ~ "version = " && !version { v = $0; sub(/.*version = "/, "", v); sub(/".*/, "", v); version = v }
    found && $0 ~ key " = " { v = $0; sub(".*" key " = \"", "", v); sub(/".*/, "", v); gsub(/\$\{version\}/, version, v); print v; exit }
  ' "$registry"
}

pinned_sha256() {
  field_of "$1" hash | sed 's/^sha256-//' | base64 -d | od -An -tx1 | tr -d ' \n'
}

verify_pleno_dlp() {
  local name="pleno-dlp" url version base file
  url=$(field_of "$name" url)
  version=$(field_of "$name" version)
  base=${url%/*}
  file=${url##*/}
  curl -fsSL --retry 3 "$url" -o "$work/$file"
  curl -fsSL --retry 3 "$base/checksums.txt" -o "$work/checksums.txt"
  curl -fsSL --retry 3 "$base/checksums.txt.sigstore.json" -o "$work/checksums.txt.sigstore.json"
  cosign verify-blob "$work/checksums.txt" --bundle "$work/checksums.txt.sigstore.json" \
    --certificate-identity-regexp '^https://github.com/plenoai/pleno-dlp/\.github/workflows/' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com >/dev/null
  (cd "$work" && grep -E "  $file\$" checksums.txt | sha256sum -c --quiet -)
  [ "$(sha256sum "$work/$file" | cut -d' ' -f1)" = "$(pinned_sha256 "$name")" ]
  echo "ok: $name $version (sigstore)"
}

verify_node() {
  local name="node-darwin-arm64" url version base file
  url=$(field_of "$name" url)
  version=$(field_of "$name" version)
  base=${url%/*}
  file=${url##*/}
  curl -fsSL --retry 3 "$url" -o "$work/$file"
  curl -fsSL --retry 3 "$base/SHASUMS256.txt.asc" -o "$work/SHASUMS256.txt.asc"
  curl -fsSL --retry 3 https://github.com/nodejs/release-keys/raw/HEAD/gpg/pubring.kbx -o "$work/node-keys.kbx"
  gpgv --keyring "$work/node-keys.kbx" --output "$work/SHASUMS256.txt" "$work/SHASUMS256.txt.asc" 2>/dev/null
  (cd "$work" && grep -E "  $file\$" SHASUMS256.txt | sha256sum -c --quiet -)
  [ "$(sha256sum "$work/$file" | cut -d' ' -f1)" = "$(pinned_sha256 "$name")" ]
  echo "ok: $name $version (gpg)"
}

verify_pleno_dlp
verify_node
