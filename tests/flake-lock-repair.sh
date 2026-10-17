#!/usr/bin/env bash
# flake-lock-repair の対象判定と revert を、bare repo を origin にした実 git で固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$root/scripts/flake-lock-repair.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bot_name="github-actions[bot]"
bot_mail="41898282+github-actions[bot]@users.noreply.github.com"

git init --quiet --bare --initial-branch=main "$tmp/origin.git"
git clone --quiet "$tmp/origin.git" "$tmp/work" 2>/dev/null

# CI には署名鍵がない。署名を強制した config でも revert が通ることを固定する
cat >"$tmp/gitconfig" <<'EOF'
[commit]
	gpgsign = true
[gpg]
	format = ssh
[user]
	signingkey = /nonexistent/key.pub
EOF

cd "$tmp/work"
git config user.name tester
git config user.email tester@example.com
printf 'lock-v1\n' >flake.lock
git add flake.lock
git commit --quiet -m "base"
git push --quiet origin main

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

sync() {
  git fetch --quiet origin "+refs/heads/main:refs/remotes/origin/main"
  git reset --quiet --hard origin/main
}

tip_subject() {
  git fetch --quiet origin "+refs/heads/main:refs/remotes/origin/main"
  git log -1 --format=%s origin/main
}

n=0
bump() {
  local author=${1:-bot}
  local extra=${2:-}
  n=$((n + 1))
  printf 'lock-broken-%d\n' "$n" >flake.lock
  if [ -n "$extra" ]; then
    printf 'other\n' >"$extra"
  fi
  git add flake.lock
  if [ -n "$extra" ]; then
    git add "$extra"
  fi
  if [ "$author" = bot ]; then
    GIT_AUTHOR_NAME="$bot_name" GIT_AUTHOR_EMAIL="$bot_mail" \
      GIT_COMMITTER_NAME="$bot_name" GIT_COMMITTER_EMAIL="$bot_mail" \
      git commit --quiet -m "chore: nix flake update"
  else
    git commit --quiet -m "chore: nix flake update"
  fi
  git push --quiet origin main
}

run_repair() {
  local build_cmd=$1
  set +e
  out=$(GIT_CONFIG_GLOBAL="$tmp/gitconfig" "$script" . "$build_cmd" 2>&1)
  status=$?
  set -e
}

# bot 単独の flake.lock bump は revert し、戻した tree を build してから push する
bump bot
run_repair true
[ "$status" -eq 0 ] || fail "repair exited $status: $out"
case "$out" in
*repair=repaired*) ;;
*) fail "expected repair=repaired: $out" ;;
esac
[ "$(cat flake.lock)" = "lock-v1" ] || fail "revert did not restore flake.lock"
case "$(tip_subject)" in
Revert*) ;;
*) fail "origin/main tip is not a revert: $(tip_subject)" ;;
esac

# 人手の commit は対象外
sync
bump human
before=$(git rev-parse origin/main)
run_repair true
[ "$status" -eq 0 ] || fail "human commit repair exited $status: $out"
case "$out" in
*repair=skipped*) ;;
*) fail "expected repair=skipped for human commit: $out" ;;
esac
[ "$(git rev-parse origin/main)" = "$before" ] || fail "human commit was rewritten"

# flake.lock 以外も触る bot commit は対象外
sync
bump bot extra.txt
before=$(git rev-parse origin/main)
run_repair true
[ "$status" -eq 0 ] || fail "multi-file repair exited $status: $out"
case "$out" in
*repair=skipped*) ;;
*) fail "expected repair=skipped for multi-file bump: $out" ;;
esac
[ "$(git rev-parse origin/main)" = "$before" ] || fail "multi-file bump was rewritten"

# 戻した tree も壊れている時は push せず人手に渡す
sync
bump bot
before=$(git rev-parse origin/main)
run_repair false
[ "$status" -eq 1 ] || fail "expected exit 1 when the reverted tree still fails: $status"
case "$out" in
*repair=manual*) ;;
*) fail "expected repair=manual: $out" ;;
esac
[ "$(git rev-parse origin/main)" = "$before" ] || fail "broken revert was pushed"

printf '%s\n' 'ok: bot flake.lock bump は revert して push、人手 commit と多ファイル bump と再失敗は触らない'
