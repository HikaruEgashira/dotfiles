#!/usr/bin/env bash
set -euo pipefail

known=$1
unexpected=0
while IFS= read -r label; do
  [ -n "$label" ] || continue
  case "$label" in
  com.stablyai.orca.terminal.?* | dev.herdr.server.?*) continue ;;
  esac
  if ! printf '%s\n' "$known" | grep -qxF "$label"; then
    printf '  UNKNOWN  %s\n' "$label"
    unexpected=1
  fi
done

if [ "$unexpected" -eq 1 ]; then
  echo ""
  echo "declare it in docs/launchd.md or remove it"
  exit 1
fi
echo "OK: no unexpected third-party launchd agents"
