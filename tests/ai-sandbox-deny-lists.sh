#!/usr/bin/env bash
# ai-sandbox の deny リストが credential 保管場所と永続化経路を覆っていることを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_nix="$root/modules/programs/harness/ai-sandbox.nix"

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
  .config/gh/hosts.yml
  .config/herdr/plugins/config
  .hermes/.env
  .local/share/artex/artex-secrets
  .local/share/artex/local.env
  .terraform.d/credentials.tfrc.json
  .npmrc
  .local/share/opencode
  .claude.json
  .zsh_history
  .config/nix/nix.conf
  .aws/sso
  .aws/cli
  .aws/credentials
  .aws/login
)
for path in "${secrets[@]}"; do
  assert_list_has secrets "$path"
done

# ~/.aws/config は profile 解決に要るので読ませ、token cache の子 path だけ deny する
# shellcheck disable=SC2016 # Match the literal Nix home interpolation.
if grep -Fq '"${home}/.aws"' <<<"$(list_body secrets)"; then
  printf '%s\n' 'FAIL: secrets denies ~/.aws entirely; aws cannot resolve profiles inside the sandbox' >&2
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

# codex は ~/.aws を組み込み deny するため read で上書きし、token cache は secrets の子 path deny に任せる
# shellcheck disable=SC2016 # Match the literal Nix home interpolation.
grep -Fq '"${home}/.aws" = "read";' "$source_nix"
grep -Fq 'codexPersistence = lib.filter (p: !builtins.elem p codexReadable) persistence;' "$source_nix"
grep -Fq '// lib.genAttrs secrets (_: "deny")' "$source_nix"
grep -Fq '// lib.genAttrs codexPersistence (_: "deny")' "$source_nix"

printf '%s\n' 'ok: ai-sandbox denies credential stores and persistence without breaking codex reads'

# ghtkn / ssh agent / aws broker の socket だけを通す。allowAllUnixSockets は docker.sock 等まで開くため使わない
grep -Fq 'ghtkn/agent.sock' "$source_nix"
grep -Fq 'aws-cred/agent.sock' "$source_nix"
grep -Fq 'allowUnixSockets = unixSockets;' "$source_nix"
# shellcheck disable=SC2016
grep -Fq 'unix_sockets=${unixSocketsToml}' "$source_nix"
if grep -Fq 'allowAllUnixSockets = true' "$source_nix"; then
  printf '%s\n' 'FAIL: allowAllUnixSockets reopens every unix socket' >&2
  exit 1
fi

# sandbox には署名 agent だけを渡し、認証鍵の agent で外部 host に ssh させない
grep -Fq 'sshAuthSock = config.home.sessionVariables.SSH_SIGN_AUTH_SOCK;' "$source_nix"
if grep -Fq 'SSH_AUTH_SOCK;' "$source_nix" || grep -Fq 'ssh-agent.sock' "$source_nix"; then
  printf '%s\n' 'FAIL: ai-sandbox exposes the ssh auth agent socket' >&2
  exit 1
fi

printf '%s\n' 'ok: ai-sandbox exposes only ghtkn, ssh sign agent and aws broker sockets'

# network proxy 有効時も push / gh api / AWS API が通るよう domain を許可する
grep -Fq '"github.com"' "$source_nix"
grep -Fq '"api.github.com"' "$source_nix"
grep -Fq '"*.amazonaws.com"' "$source_nix"
# shellcheck disable=SC2016
grep -Fq 'domains=${codexDomainsToml}' "$source_nix"

# sandbox では hosts.yml が denyRead されるため、gh は token を含まない config dir へ逃がす
# shellcheck disable=SC2016
grep -Fq 'GH_CONFIG_DIR="$HOME/.cache/ai-sandbox/gh"' "$root/lib/package-registry.nix"

printf '%s\n' 'ok: codex proxy allows github domains and gh falls back to a tokenless config dir'

# ghtkn の socket 親 dir は許可しつつ、暗号化 token store は sandbox に見せない
# shellcheck disable=SC2016
grep -Fq '"${config.xdg.cacheHome}/ghtkn/agent"' "$source_nix"

printf '%s\n' 'ok: ghtkn encrypted token store stays out of the sandbox'

# export した PAT / text backend を claude sandbox に継承させず、token 取得経路を agent socket に固定する
grep -Fq 'unset GHTKN_GITHUB_TOKEN GHTKN_BACKEND GHTKN_TEXT_BACKEND_DIR' "$source_nix"
# hikaevi の installation token cache は sandbox の gh が使う前提なので deny 対象外
if grep -Fq 'hikaevi' <<<"$(list_body secrets)"; then
  printf '%s\n' 'FAIL: ~/.cache/hikaevi is denied; the sandbox gh wrapper needs its installation token' >&2
  exit 1
fi

printf '%s\n' 'ok: claude sandbox cannot inherit a PAT and keeps the hikaevi installation token cache'
