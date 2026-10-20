#!/usr/bin/env bash
# ai-sandbox の deny リストが credential 保管場所と永続化経路を覆っていることを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/ai-sandbox.nix"

list_body() {
  awk -v target="$1" '
    $0 == "  " target " = [" { inside = 1; next }
    inside && $0 == "  ];" { exit }
    inside { print }
  ' "$source_nix"
}

assert_list_has() {
  local list=$1 path=$2 body
  body=$(list_body "$list")
  if ! grep -Fq "\"\${home}/${path}\"" <<<"$body"; then
    printf '%s\n' "FAIL: ${list} does not deny ${path}" >&2
    exit 1
  fi
}

secrets=(
  .aws
  .terraform.d/credentials.tfrc.json
  .npmrc
  .local/share/opencode
  .claude.json
  .zsh_history
  .config/nix/nix.conf
)
for path in "${secrets[@]}"; do
  assert_list_has secrets "$path"
done

if grep -Fq "\"\${home}/.aws\"" <<<"$(list_body writable)"; then
  printf '%s\n' 'FAIL: writable unexpectedly allows ~/.aws' >&2
  exit 1
fi

persistence=(
  .zshrc
  .zshenv
  .zprofile
  .bashrc
  .bash_profile
  .profile
  .config/git/hooks
  .claude/CLAUDE.md
  .codex/AGENTS.md
  .config/opencode/AGENTS.md
  .pi/agent/APPEND_SYSTEM.md
  .claude/settings.json
  .codex/config.toml
  .config/opencode/opencode.json
  .config/ai-sandbox
  .config/claude/sandbox.json
)
for path in "${persistence[@]}"; do
  assert_list_has persistence "$path"
done

# codex は読む必要のある設定を deny すると起動できないため、write 保護の対象から外す
for path in .codex/AGENTS.md .codex/config.toml .config/ai-sandbox; do
  assert_list_has codexReadable "$path"
done

grep -Fq 'codexPersistence = lib.filter (p: !builtins.elem p codexReadable) persistence;' "$source_nix"
grep -Fq '// lib.genAttrs secrets (_: "deny")' "$source_nix"
grep -Fq '// lib.genAttrs codexPersistence (_: "deny")' "$source_nix"

printf '%s\n' 'ok: ai-sandbox denies credential stores and persistence without breaking codex reads'
