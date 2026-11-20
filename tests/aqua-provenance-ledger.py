#!/usr/bin/env python3
"""aqua.yaml の全 package が scripts/aqua-provenance.sh の検証対象か provenance-ledger.tsv にあることを offline で確かめる。"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
aqua = root / "modules/programs/aqua"


def check(aqua_text: str, script_text: str, ledger_text: str) -> list[str]:
    errors = []
    packages = re.findall(r"^  - name: (.+)@\S+$", aqua_text, re.M)
    verified = set(re.findall(r"\bversion_of (\S+)\)", script_text))
    ledger = {}
    lines = ledger_text.splitlines()
    if not lines or lines[0] != "package\tprovenance":
        errors.append("provenance-ledger.tsv: header must be 'package<TAB>provenance'")
    for n, line in enumerate(lines[1:], 2):
        cols = line.split("\t")
        if len(cols) != 2 or not re.fullmatch(r"accepted: \S.*", cols[1]):
            errors.append(f"provenance-ledger.tsv:{n}: invalid row {line!r}")
            continue
        if cols[0] in ledger:
            errors.append(f"{cols[0]}: duplicate ledger row")
        ledger[cols[0]] = cols[1]
    for name in packages:
        if name not in verified and name not in ledger:
            errors.append(f"{name}: neither verified by scripts/aqua-provenance.sh nor in ledger")
        if name in verified and name in ledger:
            errors.append(f"{name}: stale ledger row, already verified by scripts/aqua-provenance.sh")
    for name in ledger:
        if name not in packages:
            errors.append(f"{name}: stale ledger row, not in aqua.yaml")
    for name in verified:
        if name not in packages:
            errors.append(f"{name}: verified by scripts/aqua-provenance.sh but not in aqua.yaml")
    return errors


def main() -> int:
    aqua_text = (aqua / "aqua.yaml").read_text()
    script_text = (root / "scripts/aqua-provenance.sh").read_text()
    ledger_text = (aqua / "provenance-ledger.tsv").read_text()
    errors = check(aqua_text, script_text, ledger_text)
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    if errors:
        return 1
    if not check(aqua_text, script_text, "package\tprovenance\n"):
        print("FAIL: guard accepted an empty ledger", file=sys.stderr)
        return 1
    if not check(aqua_text, script_text, ledger_text + "gone/pkg\taccepted: x\n"):
        print("FAIL: guard accepted a stale ledger row", file=sys.stderr)
        return 1
    print("ok: aqua provenance ledger")
    return 0


if __name__ == "__main__":
    sys.exit(main())
