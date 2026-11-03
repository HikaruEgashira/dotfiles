#!/usr/bin/env python3
"""gh extension dir (~/.local/share/gh/extensions) の唯一の走査実装。

gh のレイアウトは「entry 名 = 実行ファイル名 (gh-<name>)、local install は clone への symlink」。
ghq-clean は symlink の target を保護対象に、audit は status を判定に使う。
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

DEFAULT_DIR = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "gh" / "extensions"


@dataclass(frozen=True)
class Extension:
    name: str
    status: str  # OK | DANGLING | BROKEN | SKIP
    detail: str
    target: str | None  # symlink 型の解決先 (未解決でも返す)


def scan(directory: Path = DEFAULT_DIR) -> list[Extension]:
    try:
        entries = sorted(directory.iterdir())
    except FileNotFoundError:
        return []
    result = []
    for entry in entries:
        name = entry.name
        target = str(entry.resolve(strict=False)) if entry.is_symlink() else None
        if not name.startswith("gh-"):
            result.append(Extension(name, "SKIP", "gh- prefix が無く gh は読まない", target))
            continue
        origin = f"symlink -> {os.readlink(entry)}" if target else "managed"
        if target and not entry.exists():
            result.append(Extension(name, "DANGLING", f"symlink 先が無い: {os.readlink(entry)}", target))
        elif not entry.is_dir():
            result.append(Extension(name, "BROKEN", f"directory ではない ({origin})", target))
        elif not (entry / name).is_file():
            result.append(Extension(name, "BROKEN", f"{name} が無い ({origin})", target))
        elif not os.access(entry / name, os.X_OK):
            result.append(Extension(name, "BROKEN", f"{name} が実行可能でない ({origin})", target))
        else:
            result.append(Extension(name, "OK", origin, target))
    return result


def symlink_targets(directory: Path = DEFAULT_DIR) -> frozenset[str]:
    return frozenset(e.target for e in scan(directory) if e.target)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: gh_extensions.py <extensions-dir>", file=sys.stderr)
        return 64
    directory = Path(argv[1])
    print(f"## gh extensions ({directory})\n")
    if not directory.is_dir():
        print("OK: gh extension directory is absent")
        return 0
    extensions = scan(directory)
    for e in extensions:
        print(f"  {e.status:<9} {e.name:<14} {e.detail}")
    print()
    if any(e.status in ("DANGLING", "BROKEN") for e in extensions):
        print("壊れた gh extension あり: 復旧は docs/operations.md §4.8")
        return 1
    print(f"OK: {len(extensions)} gh extensions resolve to an executable")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
