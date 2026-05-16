#!/usr/bin/env python3
"""Stop hook: last line of assistant response を say コマンドで発話する"""

import json
import subprocess
import sys


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # stop_hook_active が True の場合はスキップ（無限ループ防止）
    if data.get("stop_hook_active"):
        sys.exit(0)

    message = data.get("last_assistant_message", "")
    if not message:
        sys.exit(0)

    # 最後の非空行を取得
    lines = [line.strip() for line in message.splitlines() if line.strip()]
    if not lines:
        sys.exit(0)

    last_line = lines[0]

    subprocess.run(
        ["/Users/hikae/ghq/github.com/HikaruEgashira/say/say", last_line],
        check=False,
    )


if __name__ == "__main__":
    main()
