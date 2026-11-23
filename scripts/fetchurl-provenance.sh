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

require_field() {
  local value
  value=$(field_of "$1" "$2")
  if [ -z "$value" ]; then
    echo "FAIL: $1: $2 not found in lib/package-registry.nix" >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

pinned_sha256() {
  require_field "$1" hash | sed 's/^sha256-//' | base64 -d | od -An -tx1 | tr -d ' \n'
}

verify_pleno_dlp() {
  local name="pleno-dlp" url version base file
  url=$(require_field "$name" url)
  version=$(require_field "$name" version)
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

verify_pleno_dlp
