#!/usr/bin/env python3
"""pi.nix の npm pin と pi-npm の package.json / lockfile / 来歴 ledger の整合を offline で確かめる。"""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
pkgdir = root / "modules/programs/harness/pi-npm"


def check(pins: dict, lock: dict, ledger: dict) -> list[str]:
    errors = []
    lock_root = lock["packages"][""].get("dependencies", {})
    if lock_root != pins:
        errors.append(f"package-lock.json root deps {lock_root} != package.json {pins}")
    installed = {
        k.split("node_modules/")[-1]
        for k in lock["packages"]
        if k.startswith("node_modules/")
    }
    for name in sorted(installed - ledger.keys()):
        errors.append(f"{name}: provenance missing in provenance.json")
    for name in sorted(ledger.keys() - installed):
        errors.append(f"{name}: stale provenance entry")
    for name, value in ledger.items():
        if value != "ci: npm audit signatures" and not re.fullmatch(r"accepted: \S.*", value):
            errors.append(f"{name}: invalid provenance {value!r}")
    return errors


def main() -> int:
    pins = json.loads((pkgdir / "package.json").read_text())["dependencies"]
    lock = json.loads((pkgdir / "package-lock.json").read_text())
    ledger = json.loads((pkgdir / "provenance.json").read_text())
    errors = check(pins, lock, ledger)
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
