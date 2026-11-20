#!/usr/bin/env python3
"""lib/package-registry.nix の fetchurl が全て CI 検証か accepted 理由を持つことを offline で確かめる。"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
registry = root / "lib/package-registry.nix"
script = root / "scripts/fetchurl-provenance.sh"
CI = "ci: scripts/fetchurl-provenance.sh"


def check(text: str, script_text: str) -> list[str]:
    errors = []
    blocks = re.split(r"\bmkDerivation\b", text)[1:]
    fetches = len(re.findall(r"\bfetchurl\s*\{", text))
    seen = 0
    for block in blocks:
        if not re.search(r"\bfetchurl\s*\{", block):
            continue
        seen += 1
        name = re.search(r'pname = "([^"]+)"', block)
        name = name.group(1) if name else "?"
        prov = re.search(r'passthru\.provenance = "([^"]*)";', block)
        if not prov:
            errors.append(f"{name}: provenance missing")
            continue
        value = prov.group(1)
        if value == CI:
            if f'"{name}"' not in script_text:
                errors.append(f"{name}: not verified in scripts/fetchurl-provenance.sh")
        elif not re.fullmatch(r"accepted: \S.*", value):
            errors.append(f"{name}: invalid provenance {value!r}")
    if seen != fetches:
        errors.append(f"{fetches - seen} fetchurl outside a mkDerivation block")
    return errors


def main() -> int:
    text = registry.read_text()
    script_text = script.read_text()
    errors = check(text, script_text)
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    if errors:
        return 1
    stripped = re.sub(r'\n\s*passthru\.provenance = "[^"]*";', "", text, count=1)
    if not check(stripped, script_text):
        print("FAIL: guard accepted a registry with a provenance removed", file=sys.stderr)
        return 1
    print("ok: fetchurl provenance")
    return 0


if __name__ == "__main__":
    sys.exit(main())
