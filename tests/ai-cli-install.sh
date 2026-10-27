#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export AI_CLI_TEST_ROOT="$tmp/native" AI_CLI_TEST_LOG="$tmp/downloads"
mkdir -p "$tmp/bin"
# shellcheck disable=SC2016
sed 's/\$HOME/\$AI_CLI_TEST_ROOT/g' "$root/modules/programs/ai-cli-install.sh" >"$tmp/install.sh"
cat >"$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$2" >>"$AI_CLI_TEST_LOG"
if [ "${FAIL_DOWNLOAD:-0}" = 1 ]; then
  printf 'touch "%s/partial-script-executed"\n' "$AI_CLI_TEST_ROOT" >"$4"
  exit 22
fi
case "$2" in
https://chatgpt.com/codex/install.sh)
  [ "$CODEX_NON_INTERACTIVE" = 1 ]
  binary="$AI_CLI_TEST_ROOT/.local/bin/codex"
  ;;
https://claude.ai/install.sh) binary="$AI_CLI_TEST_ROOT/.local/bin/claude" ;;
https://opencode.ai/v2/install) binary="$AI_CLI_TEST_ROOT/.opencode/bin/opencode" ;;
*) exit 1 ;;
esac
{
  printf 'set -eu\n'
  if [[ "$binary" == */opencode ]]; then
    printf '[ "$1" = --no-modify-path ]\n'
  fi
  printf 'mkdir -p "%s"\n' "$(dirname "$binary")"
  printf 'printf "#!/bin/sh\\nexit 0\\n" > "%s"\n' "$binary"
  printf 'chmod +x "%s"\n' "$binary"
  printf 'exit "${FAIL_INSTALL:-0}"\n'
} >"$4"
SH
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"

bash "$tmp/install.sh"
[ "$(wc -l <"$AI_CLI_TEST_LOG" | tr -d ' ')" = 3 ]
bash "$tmp/install.sh"
[ "$(wc -l <"$AI_CLI_TEST_LOG" | tr -d ' ')" = 3 ]

rm "$AI_CLI_TEST_ROOT/.local/bin/codex"
if FAIL_DOWNLOAD=1 bash "$tmp/install.sh"; then
  echo 'download failure was ignored' >&2
  exit 1
fi
[ ! -e "$AI_CLI_TEST_ROOT/partial-script-executed" ]
if FAIL_INSTALL=1 bash "$tmp/install.sh"; then
  echo 'installer failure was ignored' >&2
  exit 1
fi
rm "$AI_CLI_TEST_ROOT/.local/bin/codex"
bash "$tmp/install.sh"
[ "$(wc -l <"$AI_CLI_TEST_LOG" | tr -d ' ')" = 6 ]
echo 'ok: bootstrap, no-op, download/install failure, retry'
