#!/usr/bin/env bash
set -u

trust_helper="$HOME/.local/bin/mise-trust-repo"
if [ -x "$trust_helper" ]; then
  "$trust_helper" || echo "pre-commit: mise config trust failed; continuing" >&2
fi

if command -v pleno-dlp >/dev/null 2>&1; then
  if scan_output=$(pleno-dlp hooks run git --fail-on high 2>&1); then
    [ -z "$scan_output" ] || printf '%s\n' "$scan_output"
  else
    rc=$?
    case "$scan_output" in
    # rc 1 means findings, but an untrusted config (singular or plural) is tooling state, not a finding.
    *"not trusted"*)
      printf '%s\n' "$scan_output" >&2
      echo "pre-commit: mise config is untrusted; skipping secret scan" >&2
      ;;
    *)
      printf '%s\n' "$scan_output" >&2
      if [ "$rc" -eq 1 ]; then
        exit 1
      fi
      echo "pre-commit: pleno-dlp exited $rc; skipping secret scan" >&2
      ;;
    esac
  fi
else
  echo "pre-commit: pleno-dlp not found on PATH; skipping secret scan" >&2
fi

local_hook="$(git rev-parse --git-dir)/hooks/pre-commit"
if [ -x "$local_hook" ]; then
  exec "$local_hook" "$@"
fi
