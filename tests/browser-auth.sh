#!/usr/bin/env bash
# approver の署名とアクセス判定、および vault をシンクライアントだけに置く構成 (threat-model F13) を確かめる
set -euo pipefail
cd "$(dirname "$0")/.."
nix eval --raw '.#checks.x86_64-linux.browser-auth-tiers.name' >/dev/null
# shellcheck disable=SC2016 # ${...} は nix の式として渡す
nix shell --impure --expr \
  '(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}.python3.withPackages (ps: [ ps.cryptography ])' \
  --command python3 -I tests/browser-auth-approver.py
