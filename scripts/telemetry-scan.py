#!/usr/bin/env python3
"""Detect telemetry in installed tools and fail on tools the ledger does not classify.

usage: telemetry-scan.py <ledger.json> [--warn] [--json] <root>...
A root is a bin directory, the Aqua pkgs directory, or an Applications directory.
"""

import json
import mmap
import os
import re
import sys

ENV_RE = re.compile(
    rb"[A-Z][A-Z0-9_]*(?:TELEMETRY|ANALYTICS|DO_NOT_TRACK|USAGE_REPORT|CRASH_REPORT|ERROR_REPORTING|SEND_METRICS)[A-Z0-9_]*"
)
# OpenTelemetry semantic-convention constants and runtime internals are not opt-out switches
ENV_IGNORE = re.compile(
    rb"^(?:OTEL_|ATTR_|SEMRESATTRS_|NODE_API_|TEST_TELEMETRY|NOOP_TELEMETRY|LLVM_DISABLE_CRASH_REPORT|GO_TELEMETRY_CHILD|GLOBAL_TELEMETRY_PROVIDER)"
)
HOST_RE = re.compile(rb"https://((?:[a-z0-9-]+\.)+[a-z]{2,})")
HOST_HINT = re.compile(
    rb"posthog|sentry|segment\.(?:io|com)|amplitude|mixpanel|statsig|featuregates|datadoghq|honeycomb|axiom\.co|bugsnag|rollbar|logtail|telemetry|analytics|ingest|intake|crashlytics|appcenter|newrelic|launchdarkly|^log\.|^logheap\."
)
# documentation links and spec URLs are not endpoints
HOST_IGNORE = re.compile(rb"^(?:docs?\.|mcp\.|opentelemetry\.io$)|https?$|[a-z](?:com|io|net|dev)[a-z]{3,}$")
MIN_SIZE = 64 * 1024


CACHE = {}


def scan_file(path):
    try:
        st = os.stat(path)
    except OSError:
        return set(), set()
    key = f"{st.st_size}:{int(st.st_mtime)}"
    hit = CACHE.get(path)
    if hit and hit[0] == key:
        return set(hit[1]), set(hit[2])
    envs, hosts = _scan_file(path)
    CACHE[path] = [key, sorted(envs), sorted(hosts)]
    return envs, hosts


def _scan_file(path):
    envs, hosts = set(), set()
    try:
        with open(path, "rb") as f:
            if os.fstat(f.fileno()).st_size < MIN_SIZE:
                return envs, hosts
            with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as m:
                for e in ENV_RE.findall(m):
                    if not ENV_IGNORE.match(e):
                        envs.add(e.decode())
                for h in HOST_RE.findall(m):
                    if HOST_HINT.search(h) and not HOST_IGNORE.search(h):
                        hosts.add(h.decode())
    except (OSError, ValueError):
        pass
    return envs, hosts


def is_binary_candidate(path):
    if not os.path.isfile(path):
        return False
    if path.endswith((".asar", ".js", ".mjs", ".cjs", ".node", ".dylib")):
        return True
    return os.access(path, os.X_OK)


def units(root):
    """Yield (tool id, [files]) for one root."""
    root = os.path.expanduser(root)
    if not os.path.isdir(root):
        return
    if root.rstrip("/").endswith("Applications"):
        for app in sorted(os.listdir(root)):
            if not app.endswith(".app"):
                continue
            contents = os.path.join(root, app, "Contents")
            files = []
            for dp, _, fs in os.walk(contents):
                files += [os.path.join(dp, f) for f in fs]
            yield app, [f for f in files if is_binary_candidate(f)]
        return
    if "/pkgs" in root:
        # <pkgs>/<type>/<host>/<owner>/<repo>/<version>/...
        for dp, dns, fs in os.walk(root):
            rel = os.path.relpath(dp, root).split(os.sep)
            if len(rel) == 5 and rel[1] != "registry.npmjs.org":
                tool = f"{rel[2]}/{rel[3]}"
            elif len(rel) >= 5 and rel[1] == "registry.npmjs.org":
                tool = "/".join(p for p in rel[2:4] if p != "-")
            else:
                continue
            files = []
            for d2, _, f2 in os.walk(dp):
                files += [os.path.join(d2, f) for f in f2]
            dns.clear()
            yield tool, [f for f in files if is_binary_candidate(f)]
        return
    for name in sorted(os.listdir(root)):
        real = os.path.realpath(os.path.join(root, name))
        if is_binary_candidate(real):
            # nix wrapProgram leaves .<name>-wrapped next to the <name> script
            yield re.sub(r"^\.(.*)-wrapped$", r"\1", name), [real]


def main(argv):
    warn = "--warn" in argv
    as_json = "--json" in argv
    args = [a for a in argv if not a.startswith("--")]
    with open(args[0]) as f:
        ledger = json.load(f)["tools"]
    cache_path = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "telemetry-audit.json")
    try:
        with open(cache_path) as f:
            CACHE.update(json.load(f))
    except (OSError, ValueError):
        pass
    found = {}
    for root in args[1:]:
        for tool, files in units(root):
            envs, hosts = set(), set()
            for f in files:
                e, h = scan_file(f)
                envs |= e
                hosts |= h
            if envs or hosts:
                prev = found.setdefault(tool, {"env": set(), "hosts": set()})
                prev["env"] |= envs
                prev["hosts"] |= hosts
    try:
        os.makedirs(os.path.dirname(cache_path), exist_ok=True)
        with open(cache_path, "w") as f:
            json.dump(CACHE, f)
    except OSError:
        pass
    unknown = {t: v for t, v in found.items() if t not in ledger}
    if as_json:
        print(json.dumps({t: {k: sorted(s) for k, s in v.items()} for t, v in sorted(found.items())}, indent=2))
    for tool, v in sorted(unknown.items()):
        print(f"telemetry-audit: unclassified {tool}", file=sys.stderr)
        for e in sorted(v["env"]):
            print(f"  env   {e}", file=sys.stderr)
        for h in sorted(v["hosts"]):
            print(f"  host  {h}", file=sys.stderr)
    if unknown:
        print(
            "telemetry-audit: classify each tool in lib/telemetry-ledger.json "
            "(disabled: opt-out wired up / blocked: list domains for the DNS denylist / none: no remote telemetry)",
            file=sys.stderr,
        )
        return 0 if warn else 1
    if not as_json:
        print(f"telemetry-audit: {len(found)} tools with telemetry indicators, all classified")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
