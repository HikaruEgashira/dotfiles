"""Render credentials outside the Nix store without interpreting them as YAML or shell."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def render(value, secrets):
    if isinstance(value, dict):
        return {k: render(v, secrets) for k, v in value.items()}
    if isinstance(value, list):
        return [render(v, secrets) for v in value]
    if isinstance(value, str) and re.fullmatch(r"@[A-Z_]+@", value):
        key = value[1:-1]
        if not secrets.get(key):
            raise ValueError(f"Missing credential: {key}")
        return secrets[key]
    return value


def write_private(path, value):
    fd, tmp = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(value)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main():
    template, state, vault = map(Path, sys.argv[1:])
    if (vault / "env.age").exists():
        plain = subprocess.check_output(
            ["age", "-d", "-i", str(vault / "age-se.txt"), str(vault / "env.age")], text=True
        )
    else:
        plain = (state / "secrets.env").read_text()
    secrets = {"APARTURE_API_KEY": "none"}
    for line in plain.splitlines():
        if not line or line.startswith("#"):
            continue
        name, sep, value = line.partition("=")
        if not sep or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise ValueError("Invalid credential file entry")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        secrets[name] = value
    config = render(json.loads(template.read_text()), secrets)
    write_private(state / "config.yaml", json.dumps(config) + "\n")
    write_private(state / "client-key", secrets["CLIPROXYAPI_CLIENT_KEY"] + "\n")


if __name__ == "__main__":
    main()
