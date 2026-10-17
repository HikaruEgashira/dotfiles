#!/usr/bin/env bash
# flake.lock bump が activation を壊した時だけ main を 1 commit 戻す。人手の commit は触らない。
# usage: flake-lock-repair.sh <repo> <build command...>   (build command は戻した tree の検証に使う)
set -euo pipefail

repo=${1:?repo path}
shift
if [ $# -eq 0 ]; then
  echo "usage: flake-lock-repair.sh <repo> <build command...>" >&2
  exit 2
fi
build=("$@")
push_target=${REPAIR_PUSH_URL:-origin}
bot_mail="41898282+github-actions[bot]@users.noreply.github.com"

cd "$repo"
git fetch --quiet origin "+refs/heads/main:refs/remotes/origin/main"

head=$(git rev-parse HEAD)
if [ "$head" != "$(git rev-parse origin/main)" ]; then
  echo "repair=skipped (HEAD is behind origin/main; a newer commit may already fix it)"
  exit 0
fi
if [ "$(git log -1 --format=%ae)" != "$bot_mail" ]; then
  echo "repair=skipped (tip is not the flake-update bot commit)"
  exit 0
fi

changed=$(git diff-tree --no-commit-id --name-only -r HEAD)
if [ "$changed" != "flake.lock" ]; then
  echo "repair=skipped (tip also touches: $(printf '%s' "$changed" | tr '\n' ' '))"
  exit 0
fi

git -c user.name="github-actions[bot]" -c user.email="$bot_mail" revert --no-edit "$head" >/dev/null

if ! "${build[@]}"; then
  echo "repair=manual (the previous flake.lock is broken too; nothing was pushed)"
  exit 1
fi

git push --quiet "$push_target" "HEAD:refs/heads/main"
echo "repair=repaired (reverted $(git rev-parse --short "$head") to $(git rev-parse --short HEAD))"
