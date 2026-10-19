#!/usr/bin/env bash
# mise-trust-repo が git checkout だけを対象に repo 単位で trust することを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$root/modules/programs/mise/trust-repo.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/home/.local/bin" "$tmp/repo" "$tmp/not-git" "$tmp/tools"
ln -s "$(command -v git)" "$tmp/tools/git"
printf '[env]\nFOO="bar"\n' >"$tmp/repo/mise.toml"
printf '[env]\nFOO="bar"\n' >"$tmp/not-git/mise.toml"
git -C "$tmp/repo" init --quiet

cat >"$tmp/bin/mise" <<'EOF'
#!/bin/sh
set -u
printf '%s\n' "$*" >>"${MISE_LOG:?}"
exit "${MISE_EXIT:-0}"
EOF
chmod +x "$tmp/bin/mise"

repo=$(cd "$tmp/repo" && pwd -P)
bash_bin=$(command -v bash)

run_helper() {
  local name=$1 test_path=$2 target=${3:-}
  (
    set +e
    export HOME="$tmp/home"
    export PATH="$test_path"
    export MISE_LOG="$tmp/$name.log"
    if [ -n "$target" ]; then
      "$bash_bin" "$script" "$target" >"$tmp/$name.output" 2>&1
    else
      cd "$tmp/repo"
      "$bash_bin" "$script" >"$tmp/$name.output" 2>&1
    fi
    status=$?
    set -e
    printf '%s' "$status" >"$tmp/$name.status"
  )
}

# git config を持つ repo は root 全体 (親と nested) を trust する
run_helper success "$tmp/bin:$tmp/tools"
[ "$(cat "$tmp/success.status")" -eq 0 ]
grep -qx "trust --all $repo" "$tmp/success.log"

# Git hook は non-interactive なので PATH に mise が無くても installer 既定位置を使う
rm -rf "$tmp/home/.local/bin/mise"
cp "$tmp/bin/mise" "$tmp/home/.local/bin/mise"
run_helper fallback "$tmp/tools"
[ "$(cat "$tmp/fallback.status")" -eq 0 ]
grep -qx "trust --all $repo" "$tmp/fallback.log"

# mise が無い環境は no-op (checkout を止めない)
rm -f "$tmp/home/.local/bin/mise"
run_helper no-mise "$tmp/tools"
[ "$(cat "$tmp/no-mise.status")" -eq 0 ]
[ ! -e "$tmp/no-mise.log" ]

# git repo 以外を渡されたら trust しない
run_helper not-git "$tmp/bin:$tmp/tools" "$tmp/not-git"
[ "$(cat "$tmp/not-git.status")" -eq 0 ]
[ ! -e "$tmp/not-git.log" ]

# trust の失敗は呼び出し側が警告に落とせるよう非 0 で返す
export MISE_EXIT=1
run_helper failure "$tmp/bin:$tmp/tools"
unset MISE_EXIT
[ "$(cat "$tmp/failure.status")" -eq 1 ]
grep -q 'failed to trust' "$tmp/failure.output"

printf '%s\n' 'ok: mise-trust-repo trusts cloned checkouts and falls back to ~/.local/bin/mise'
