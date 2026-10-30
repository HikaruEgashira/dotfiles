#!/usr/bin/env bash
set -euo pipefail

known=$1
launchctl_bin=$2
checker=$3

if ! listing=$("$launchctl_bin" list 2>/dev/null); then
  echo "launchd-audit: unable to enumerate the launchd user domain" >&2
  exit 2
fi

if ! printf '%s\n' "$listing" | awk 'NR == 1 { valid = (NF == 3 && $1 == "PID" && $2 == "Status" && $3 == "Label") } END { exit !valid }'; then
  echo "launchd-audit: invalid launchd list header" >&2
  exit 2
fi

labels=$(printf '%s\n' "$listing" |
  awk 'NR > 1 && $NF !~ /^(com\.apple\.|application\.)/ { print $NF }' |
  sort -u)
printf '%s\n' "$labels" | bash "$checker" "$known"
