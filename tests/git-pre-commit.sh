#!/usr/bin/env bash
# pre-commit が mise の trust 切れを secret 検出と取り違えないことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$root/modules/programs/git/pre-commit.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/home/.local/bin" "$tmp/repo" "$tmp/tools"
for bin in bash env git; do ln -s "$(command -v "$bin")" "$tmp/tools/$bin"; done
git -C "$tmp/repo" init --quiet
mkdir -p "$tmp/repo/.git/hooks"
cat >"$tmp/bin/pleno-dlp" <<'EOF'
#!/usr/bin/env bash
set -u
case "${PLENO_DLP_MODE:-ok}" in
ok) exit 0 ;;
findings)
  echo "high: staged secret found"
  exit 1
  ;;
untrusted)
  echo "mise ERROR Config files in $PWD/mise.toml are not trusted." >&2
  exit 1
  ;;
untrusted-singular)
  echo "mise ERROR Config file $PWD/mise.toml is not trusted." >&2
  exit 1
  ;;
crash)
  echo "pleno-dlp crashed" >&2
  exit 2
  ;;
esac
EOF
chmod +x "$tmp/bin/pleno-dlp"

cat >"$tmp/home/.local/bin/mise-trust-repo" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${TRUST_LOG:?}"
exit "${TRUST_EXIT:-0}"
EOF
chmod +x "$tmp/home/.local/bin/mise-trust-repo"

cat >"$tmp/repo/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
printf 'local-hook\n' >>"${LOCAL_HOOK_LOG:?}"
EOF
chmod +x "$tmp/repo/.git/hooks/pre-commit"

run_case() {
  local name=$1 mode=$2 trust_exit=$3 test_path=$4
  local log="$tmp/$name.log"
  : >"$log"
  (
    set -u
    export HOME="$tmp/home"
    export PATH="$test_path"
    export PLENO_DLP_MODE="$mode"
    export TRUST_LOG="$tmp/$name.trust.log"
    export TRUST_EXIT="$trust_exit"
    export LOCAL_HOOK_LOG="$log"
    cd "$tmp/repo"
    set +e
    output=$(bash "$script" 2>&1)
    status=$?
    set -e
    printf '%s' "$status" >"$tmp/$name.status"
    printf '%s' "$output" >"$tmp/$name.output"
  )
}

# trust helper が失敗しても pleno-dlp が通れば commit は進む
run_case trust-helper-fails ok 1 "$tmp/bin:$tmp/tools"
[ "$(cat "$tmp/trust-helper-fails.status")" -eq 0 ]
grep -q local-hook "$tmp/trust-helper-fails.log"
grep -q 'mise config trust failed; continuing' "$tmp/trust-helper-fails.output"
grep -q '^' "$tmp/trust-helper-fails.trust.log"

# untrusted は検出ではないので、secret scan を skip して commit は進む
run_case untrusted untrusted 0 "$tmp/bin:$tmp/tools"
[ "$(cat "$tmp/untrusted.status")" -eq 0 ]
grep -q local-hook "$tmp/untrusted.log"
grep -q 'skipping secret scan' "$tmp/untrusted.output"

# 単数形の untrusted 文言も tooling state として扱う
run_case untrusted-singular untrusted-singular 0 "$tmp/bin:$tmp/tools"
[ "$(cat "$tmp/untrusted-singular.status")" -eq 0 ]
grep -q local-hook "$tmp/untrusted-singular.log"
grep -q 'skipping secret scan' "$tmp/untrusted-singular.output"

# rc 1 の実検出は従来どおり commit を止める
run_case findings findings 0 "$tmp/bin:$tmp/tools"
[ "$(cat "$tmp/findings.status")" -eq 1 ]
[ ! -e "$tmp/findings.log" ] || ! grep -q local-hook "$tmp/findings.log"
grep -q 'staged secret found' "$tmp/findings.output"

# 検出以外の tooling crash は commit を止めない
run_case crash crash 0 "$tmp/bin:$tmp/tools"
[ "$(cat "$tmp/crash.status")" -eq 0 ]
grep -q local-hook "$tmp/crash.log"
grep -q 'skipping secret scan' "$tmp/crash.output"

# pleno-dlp 自体が無い環境でも local hook は実行する
run_case missing ok 0 "$tmp/tools"
[ "$(cat "$tmp/missing.status")" -eq 0 ]
grep -q local-hook "$tmp/missing.log"
grep -q 'pleno-dlp not found' "$tmp/missing.output"

printf '%s\n' 'ok: pre-commit keeps tooling/trust failures separate from secret findings'
