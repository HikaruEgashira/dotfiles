#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
installer=""
trap 'if [ -n "$installer" ]; then rm -f "$installer"; fi' EXIT

install_native() {
  local binary=$1 url=$2
  shift 2
  if [ -x "$binary" ]; then
    return
  fi
  installer=$(mktemp)
  curl -fsSL "$url" -o "$installer"
  bash "$installer" "$@"
  test -x "$binary"
  rm -f "$installer"
  installer=""
}

CODEX_NON_INTERACTIVE=1 install_native \
  "$HOME/.local/bin/codex" https://chatgpt.com/codex/install.sh
install_native "$HOME/.local/bin/claude" https://claude.ai/install.sh
install_native "$HOME/.opencode/bin/opencode" https://opencode.ai/v2/install --no-modify-path
