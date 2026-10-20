#!/usr/bin/env bash
# mise.nix の trust 設定と git hook への配線を固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
file="$root/modules/programs/mise.nix"
git="$root/modules/programs/git.nix"
pre_commit="$root/modules/programs/git/pre-commit.sh"

grep -q 'trusted_config_paths = \[ "~/ghq" \]' "$file"
grep -q 'MISE_TRUSTED_CONFIG_PATHS' "$file"
grep -q 'homeDirectory}/ghq' "$file"
grep -q 'mise-trust-repo' "$file"

grep -q 'mise-trust-repo' "$git"
grep -q 'post-checkout' "$git"
grep -q 'post-merge' "$git"
grep -q 'mise-trust-repo' "$pre_commit"

printf '%s\n' 'ok: mise.nix declares trust paths and git hooks invoke the repo trust helper'
