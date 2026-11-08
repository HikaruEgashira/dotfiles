#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/aqua-policy-check.sh"
aqua="$root/modules/programs/aqua"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bash "$checker" "$aqua/aqua.yaml" "$aqua/aqua-policy.yaml"

cat >"$tmp/policy.yaml" <<'YAML'
packages:
  - name: foo/bar
    registry: local
  - name: baz/qux
YAML

cat >"$tmp/ok.yaml" <<'YAML'
packages:
  - name: foo/bar@v1.0.0
    registry: local
  - name: baz/qux@v2.0.0
YAML
bash "$checker" "$tmp/ok.yaml" "$tmp/policy.yaml"

cat >"$tmp/missing.yaml" <<'YAML'
packages:
  - name: foo/bar@v1.0.0
    registry: local
  - name: new/tool@v0.1.0
    registry: local
YAML
if output=$(bash "$checker" "$tmp/missing.yaml" "$tmp/policy.yaml" 2>&1); then
  echo 'FAIL: package missing from policy accepted' >&2
  exit 1
fi
[[ $output == *"NOT ALLOWED  new/tool local"* ]]

cat >"$tmp/registry.yaml" <<'YAML'
packages:
  - name: baz/qux@v2.0.0
    registry: local
YAML
if output=$(bash "$checker" "$tmp/registry.yaml" "$tmp/policy.yaml" 2>&1); then
  echo 'FAIL: package with unallowed registry accepted' >&2
  exit 1
fi
[[ $output == *"NOT ALLOWED  baz/qux local"* ]]

printf '%s\n' 'ok: policy-covered packages accepted; unlisted package and registry rejected'
