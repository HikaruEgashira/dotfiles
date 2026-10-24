#!/usr/bin/env bash
set -u

if command -v pleno-dlp >/dev/null 2>&1; then
  if scan_output=$(pleno-dlp hooks run git --fail-on high 2>&1); then
    [ -z "$scan_output" ] || printf '%s\n' "$scan_output"
  else
    rc=$?
    printf '%s\n' "$scan_output" >&2
    [ "$rc" -eq 1 ] && exit 1
    echo "pre-commit: pleno-dlp exited $rc; skipping secret scan" >&2
  fi
else
  echo "pre-commit: pleno-dlp not found on PATH; skipping secret scan" >&2
fi

local_hook="$(git rev-parse --git-dir)/hooks/pre-commit"
if [ -x "$local_hook" ]; then
  if local_output=$("$local_hook" "$@" 2>&1); then
    [ -z "$local_output" ] || printf '%s\n' "$local_output"
  else
    rc=$?
    printf '%s\n' "$local_output" >&2
    exit "$rc"
  fi
fi
