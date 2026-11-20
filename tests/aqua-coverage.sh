#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/aqua-coverage.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bash "$checker"

cat >"$tmp/registry.yaml" <<'YAML'
packages:
  - repo_owner: foo
    repo_name: bar
    checksum:
      asset: checksums.txt
  - repo_owner: baz
    repo_name: qux
YAML
cat >"$tmp/aqua.yaml" <<'YAML'
packages:
  - name: foo/bar@v1.0.0
  - name: baz/qux@v2.0.0
YAML
printf 'package\tstatus\treason\nbaz/qux\t来歴なし受容\tx\n' >"$tmp/provenance-ledger.tsv"
bash "$checker" "$tmp" >/dev/null

expect_fail() {
  if output=$(bash "$checker" "$tmp" 2>&1); then
    echo "FAIL: $1 accepted" >&2
    exit 1
  fi
  [[ $output == *"$2"* ]]
}

printf 'package\tstatus\treason\n' >"$tmp/provenance-ledger.tsv"
expect_fail 'uncovered package' 'UNCOVERED  baz/qux'

printf 'package\tstatus\treason\nbaz/qux\t来歴なし受容\tx\nfoo/bar\t来歴なし受容\tx\n' >"$tmp/provenance-ledger.tsv"
expect_fail 'ledger row for verified package' 'STALE      foo/bar (verified'

printf 'package\tstatus\treason\nbaz/qux\t来歴なし受容\tx\ngone/tool\t来歴なし受容\tx\n' >"$tmp/provenance-ledger.tsv"
expect_fail 'ledger row for removed package' 'STALE      gone/tool (not in aqua.yaml)'

printf '%s\n' 'ok: uncovered packages and stale ledger rows rejected'
