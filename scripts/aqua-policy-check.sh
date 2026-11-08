#!/usr/bin/env bash
set -euo pipefail

config=$1
policy=$2
filter='.packages[] | (.name | sub("@.*$"; "")) + " " + (.registry // "standard")'

allowed=$(yq -r "$filter" "$policy")
missing=0
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  if ! printf '%s\n' "$allowed" | grep -qxF "$entry"; then
    printf '  NOT ALLOWED  %s\n' "$entry"
    missing=1
  fi
done < <(yq -r "$filter" "$config")

if [ "$missing" -eq 1 ]; then
  echo ""
  echo "add the package to $(basename "$policy")"
  exit 1
fi
echo "OK: every aqua package is allowed by policy"
