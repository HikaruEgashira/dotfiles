#!/usr/bin/env bash
# mise.nix が global trust 設定と env fallback の両方を宣言していることを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
file="$root/modules/programs/mise.nix"

grep -q 'trusted_config_paths = \[ "~/ghq" \]' "$file"
grep -q 'MISE_TRUSTED_CONFIG_PATHS' "$file"
grep -q 'homeDirectory}/ghq' "$file"
grep -q 'mise-trust-repo' "$file"

printf '%s\n' 'ok: mise.nix declares global trust paths, env fallback, and repo helper'
