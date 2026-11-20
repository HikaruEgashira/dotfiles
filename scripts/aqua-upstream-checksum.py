#!/usr/bin/env python3
"""registry.yaml に checksum.type: github_release がある package の pin を上流 checksum asset と照合する。"""
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

root = Path(__file__).resolve().parent.parent
aqua = root / "modules/programs/aqua"


def _scalar(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def checksum_packages(registry_text: str) -> list[dict]:
    """top-level の repo_owner/repo_name/version_prefix と checksum ブロックだけを読む。"""
    pkgs, cur, in_checksum = [], None, False
    for line in registry_text.splitlines():
        if re.match(r"^  - ", line):
            cur, in_checksum = {}, False
            pkgs.append(cur)
            line = "    " + line[4:]
        if cur is None:
            continue
        m = re.match(r"^    (\w+):\s*(.*)$", line)
        if m:
            in_checksum = m.group(1) == "checksum"
            if m.group(1) in ("repo_owner", "repo_name", "version_prefix"):
                cur[m.group(1)] = _scalar(m.group(2))
            continue
        m = re.match(r"^      (\w+):\s*(.*)$", line)
        if m and in_checksum:
            cur.setdefault("checksum", {})[m.group(1)] = _scalar(m.group(2))
    return [
        p for p in pkgs
        if p.get("checksum", {}).get("type") == "github_release" and p["checksum"].get("asset")
    ]


def trim_v(s: str) -> str:
    return s[1:] if s.startswith("v") else s


def render(template: str, version: str, semver: str, asset: str) -> str:
    values = {
        ".Version": version,
        "trimV .Version": trim_v(version),
        ".SemVer": semver,
        "trimV .SemVer": trim_v(semver),
        ".Asset": asset,
    }

    def sub(m: re.Match) -> str:
        key = " ".join(m.group(1).split())
        if key not in values:
            raise ValueError(f"unsupported template variable {{{{{m.group(1)}}}}} in {template!r}")
        return values[key]

    return re.sub(r"\{\{\s*(.*?)\s*\}\}", sub, template)


def lookup(text: str, asset: str, single: bool) -> str | None:
    rows = [l.split() for l in text.splitlines() if l.strip()]
    if single and len(rows) == 1 and re.fullmatch(r"[0-9a-fA-F]{64}", rows[0][0]):
        return rows[0][0].lower()
    for row in rows:
        if len(row) >= 2 and re.fullmatch(r"[0-9a-fA-F]{64}", row[0]):
            if row[-1].lstrip("*").removeprefix("./") == asset:
                return row[0].lower()
    return None


def fetch(url: str) -> str | None:
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            return r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def ledger_names(text: str) -> set[str]:
    return {l.split("\t")[0] for l in text.splitlines()[1:] if l.strip()}


def main() -> int:
    versions = dict(re.findall(r"^  - name: (.+)@(\S+)$", (aqua / "aqua.yaml").read_text(), re.M))
    pins = json.loads((aqua / "aqua-checksums.json").read_text())["checksums"]
    skip = ledger_names((aqua / "provenance-ledger.tsv").read_text())
    failed = False
    for p in checksum_packages((aqua / "registry.yaml").read_text()):
        name = f"{p['repo_owner']}/{p['repo_name']}"
        if name not in versions:
            continue
        if name in skip:
            print(f"skip: {name} (provenance-ledger.tsv)")
            continue
        version = versions[name]
        semver = version.removeprefix(p.get("version_prefix", ""))
        prefix = f"github_release/github.com/{name}/{version}/"
        targets = [(c["id"][len(prefix):], c["checksum"].lower()) for c in pins if c["id"].startswith(prefix)]
        if not targets:
            print(f"FAIL: {name} {version}: no pin in aqua-checksums.json", file=sys.stderr)
            failed = True
            continue
        template = p["checksum"]["asset"]
        single = "{{" in template and ".Asset" in template
        cache: dict[str, str | None] = {}
        for asset, pinned in targets:
            try:
                sums_asset = render(template, version, semver, asset)
            except ValueError as e:
                print(f"FAIL: {name}: {e}", file=sys.stderr)
                return 1
            if sums_asset not in cache:
                cache[sums_asset] = fetch(f"https://github.com/{name}/releases/download/{version}/{sums_asset}")
            text = cache[sums_asset]
            if text is None:
                print(f"::warning::{name} {version}: checksum asset {sums_asset} not found upstream; record it in provenance-ledger.tsv")
                break
            upstream = lookup(text, asset, single)
            if upstream is None:
                print(f"::warning::{name} {version}: {asset} not listed in {sums_asset}; record it in provenance-ledger.tsv")
                continue
            if upstream != pinned:
                print(f"FAIL: {name} {asset}: pinned {pinned} != upstream {upstream}", file=sys.stderr)
                failed = True
                continue
            print(f"ok: {name} {asset} ({sums_asset})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
