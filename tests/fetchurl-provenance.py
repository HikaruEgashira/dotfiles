"""Every fetchurl in the package registry must be CI-verified or recorded as accepted in the ledger."""

import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
src = (root / "lib/package-registry.nix").read_text()
script = (root / "scripts/fetchurl-provenance.sh").read_text()

bindings = dict(re.findall(r"^  (\w+) =\n(.*?)(?=^  \w+ =\n|^in\n)", src, re.S | re.M))
entries = {
    m.group(1): m.group(2)
    for m in re.finditer(r"mkEntry \{\n      pkg = (\w+);\n(.*?)\n    \}\)", src, re.S)
}

errors = []
for name, body in bindings.items():
    for url in re.findall(r'fetchurl \{\n\s*url = "([^"]+)"', body):
        users = [name] + [n for n, b in bindings.items() if re.search(rf"runtimeInputs = \[[^]]*\b{name}\b", b)]
        provs = [
            p
            for u in users
            for p in re.findall(r'provenance = "([^"]+)";', entries.get(u, ""))
        ]
        if not provs:
            errors.append(f"{name}: {url} has no ledger provenance")
        for p in provs:
            if p.startswith("ci: "):
                host = url.split("${")[0].split("/releases/")[0].split("/dist/")[0]
                if host not in script:
                    errors.append(f"{name}: {url} is marked ci but not verified by the script")
            elif not p.startswith("accepted: "):
                errors.append(f"{name}: provenance must start with 'ci: ' or 'accepted: '")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("ok: fetchurl provenance coverage")
