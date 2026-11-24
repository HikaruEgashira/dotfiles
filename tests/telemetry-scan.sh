#!/usr/bin/env bash
# usage: telemetry-scan.sh [<python3> <telemetry-scan.py> <telemetry-ledger.json>]
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
py=${1:-python3} scan=${2:-$root/scripts/telemetry-scan.py} ledger=${3:-$root/lib/telemetry-ledger.json}
work=$(mktemp -d)
export XDG_CACHE_HOME="$work/cache"
mkdir -p "$work/bin"

fixture="$work/bin/newtool"
{
  head -c 70000 /dev/zero | tr '\0' 'x'
  printf 'NEWTOOL_TELEMETRY_ENABLED https://ingest.newtool.example/v1 https://docs.sentry.io/x'
} >"$fixture"
chmod +x "$fixture"

echo '{"tools":{}}' >"$work/empty.json"
if "$py" -I "$scan" "$work/empty.json" "$work/bin" 2>"$work/err"; then
  echo "FAIL: an unclassified tool passed" >&2
  exit 1
fi
grep -q 'unclassified newtool' "$work/err"
grep -q 'env   NEWTOOL_TELEMETRY_ENABLED' "$work/err"
grep -q 'host  ingest.newtool.example' "$work/err"
if grep -q 'docs.sentry.io' "$work/err"; then
  echo "FAIL: documentation hosts must be ignored" >&2
  exit 1
fi

"$py" -I "$scan" "$work/empty.json" --warn "$work/bin" 2>/dev/null

echo '{"tools":{"newtool":{"status":"none","via":"fixture"}}}' >"$work/known.json"
"$py" -I "$scan" "$work/known.json" "$work/bin" >/dev/null

# 台帳の形: status は 3 値、blocked は遮断先を持つ (他 entry 参照なら via で明示)、domain は hostname
"$py" -I - "$ledger" <<'PY'
import json, re, sys
tools = json.load(open(sys.argv[1]))["tools"]
host = re.compile(r"^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$")
bad = []
for name, t in tools.items():
    if t.get("status") not in ("disabled", "blocked", "none"):
        bad.append(f"{name}: status")
    if not t.get("via"):
        bad.append(f"{name}: via")
    for d in t.get("domains", []):
        if not host.match(d):
            bad.append(f"{name}: domain {d}")
    if t.get("status") == "blocked" and not t.get("domains") and "covered by" not in t.get("via", ""):
        bad.append(f"{name}: blocked without domains")
if bad:
    sys.exit("ledger: " + ", ".join(bad))
PY
echo "telemetry-scan: ok"
