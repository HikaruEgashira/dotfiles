#!/usr/bin/env bash
# Trust the project configs of a checkout so mise-backed hooks work on first use.
set -eu

target=${1:-}
if [ -z "$target" ]; then
  target=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
fi
[ -d "$target" ] || exit 0

git_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$git_root" ] || exit 0
root=$(cd "$git_root" && pwd -P)

mise_bin=""
if command -v mise >/dev/null 2>&1; then
  mise_bin=$(command -v mise)
elif [ -x "$HOME/.local/bin/mise" ]; then
  mise_bin="$HOME/.local/bin/mise"
fi
[ -n "$mise_bin" ] || exit 0

if ! "$mise_bin" trust --all "$root" >/dev/null 2>&1; then
  echo "mise-trust-repo: failed to trust $root" >&2
  exit 1
fi
