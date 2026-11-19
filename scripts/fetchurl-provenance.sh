#!/usr/bin/env bash
# lib/package-registry.nix の fetchurl pin が上流の署名に裏付けられた artifact を指すことを検証する。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
registry=$root/lib/package-registry.nix
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# fetchurl の url 行の直後にある hash (SRI) を hex で返す
pinned_sha256() {
  local sri
  sri=$(grep -F -A1 "$1" "$registry" | sed -nE 's|^ *hash = "sha256-(.+)";$|\1|p')
  [ -n "$sri" ]
  printf '%s' "$sri" | base64 -d | od -An -tx1 -v | tr -d ' \n'
}

fetch() {
  curl -fsSL --retry 3 "$1" -o "$2"
}

verify_pleno_dlp() {
  local url version base asset
  url=$(sed -nE 's|^ *url = "(https://github.com/plenoai/pleno-dlp/releases/download/[^"]+)";$|\1|p' "$registry")
  [ -n "$url" ]
  version=$(sed -nE 's|.*/download/(v[^/]+)/.*|\1|p' <<<"$url")
  base=${url%/*}
  asset=${url##*/}
  fetch "$base/checksums.txt" "$work/checksums.txt"
  fetch "$base/checksums.txt.sigstore.json" "$work/checksums.txt.sigstore.json"
  cosign verify-blob "$work/checksums.txt" \
    --bundle "$work/checksums.txt.sigstore.json" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp '^https://github\.com/plenoai/pleno-dlp/\.github/workflows/' >/dev/null
  [ "$(awk -v f="$asset" '$2 == f { print $1 }' "$work/checksums.txt")" = "$(pinned_sha256 "$url")" ]
  echo "ok: pleno-dlp $version (sigstore)"
}

verify_node() {
  local version file
  version=$(grep -F -B3 'https://nodejs.org/dist/' "$registry" | sed -nE 's|^ *version = "(.+)";$|\1|p')
  [ -n "$version" ]
  file=node-v$version-darwin-arm64.tar.gz
  fetch https://github.com/nodejs/release-keys/raw/HEAD/gpg-only-active-keys/pubring.kbx "$work/node-keyring.kbx"
  fetch "https://nodejs.org/dist/v$version/SHASUMS256.txt" "$work/SHASUMS256.txt"
  fetch "https://nodejs.org/dist/v$version/SHASUMS256.txt.sig" "$work/SHASUMS256.txt.sig"
  gpgv --keyring "$work/node-keyring.kbx" "$work/SHASUMS256.txt.sig" "$work/SHASUMS256.txt" 2>/dev/null
  [ "$(awk -v f="$file" '$2 == f { print $1 }' "$work/SHASUMS256.txt")" = \
    "$(pinned_sha256 "https://nodejs.org/dist/v\${version}/node-v\${version}-darwin-arm64.tar.gz")" ]
  echo "ok: node $version (GPG)"
}

verify_pleno_dlp
verify_node
