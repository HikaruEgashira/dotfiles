#!/usr/bin/env bash
# aqua.yaml の全 package が CI 検証対象か provenance-ledger.tsv のどちらか一方にだけ載ることを offline で検証する。
set -euo pipefail

aqua=${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/modules/programs/aqua}

# scripts/aqua-provenance.sh の verify_npm が npm attestation で検証する package
npm_attested=(openai/codex anomalyco/opencode)

pinned=$(yq -r '.packages[].name | sub("@.*$"; "")' "$aqua/aqua.yaml" | sort -u)
targets=$({
  printf '%s\n' "${npm_attested[@]}"
  yq -r '.packages[] | select(.checksum) | .repo_owner + "/" + .repo_name' "$aqua/registry.yaml"
} | sort -u)
ledger=$(tail -n +2 "$aqua/provenance-ledger.tsv" | cut -f1 | sort)

fail=0
while IFS= read -r pkg; do
  [ -n "$pkg" ] || continue
  in_t=$(printf '%s\n' "$targets" | grep -cxF "$pkg" || true)
  in_l=$(printf '%s\n' "$ledger" | grep -cxF "$pkg" || true)
  if [ "$in_t" -eq 0 ] && [ "$in_l" -eq 0 ]; then
    printf '  UNCOVERED  %s\n' "$pkg"
    fail=1
  elif [ "$in_t" -gt 0 ] && [ "$in_l" -gt 0 ]; then
    printf '  STALE      %s (verified, remove from ledger)\n' "$pkg"
    fail=1
  fi
done <<<"$pinned"

while IFS= read -r pkg; do
  [ -n "$pkg" ] || continue
  if ! printf '%s\n' "$pinned" | grep -qxF "$pkg"; then
    printf '  STALE      %s (not in aqua.yaml)\n' "$pkg"
    fail=1
  fi
done <<<"$ledger"

while IFS= read -r pkg; do
  [ -n "$pkg" ] || continue
  printf '  DUPLICATE  %s\n' "$pkg"
  fail=1
done < <(printf '%s\n' "$ledger" | uniq -d)

if [ "$fail" -eq 1 ]; then
  echo ""
  echo "add a checksum asset to registry.yaml or a row to provenance-ledger.tsv"
  exit 1
fi
echo "OK: every aqua package is verified or recorded in the ledger"
