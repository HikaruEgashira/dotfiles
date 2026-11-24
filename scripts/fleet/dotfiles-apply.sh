#!/bin/bash
# Fleet が root で実行する。@TARGET@ は fleet-controller が CI 済みの main commit に置き換える
set -euo pipefail

target="@TARGET@"
user=hikae
repo="/Users/$user/dotfiles"

as_user() {
  /usr/bin/sudo -u "$user" -H /bin/zsh -lc "cd '$repo' && $1"
}

case "$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)" in
Mac-Studio) host=mac-studio home_host=hikae@mac-studio ;;
*) host=hikae home_host=hikae ;;
esac

[ "$(as_user 'git symbolic-ref --short HEAD')" = main ] || {
  echo "skip: $repo is not on main" >&2
  exit 2
}
as_user 'git diff --quiet HEAD --' || {
  echo "skip: $repo has uncommitted changes" >&2
  exit 2
}

as_user 'git fetch --quiet origin main'
if [ "$(as_user 'git rev-parse HEAD')" != "$target" ]; then
  as_user "git merge --ff-only --quiet $target"
fi

home=$(as_user "nix build --no-link --print-out-paths '.#homeConfigurations.\"$home_host\".activationPackage'")
system=$(as_user "nix build --no-link --print-out-paths '.#darwinConfigurations.$host.system'")

as_user "'$home/activate' >/dev/null"
# root は他ユーザー所有の git repo を flake として評価できないので、build 済みの system を直接 activate する
if [ "$(/usr/bin/readlink /run/current-system)" != "$system" ]; then
  /nix/var/nix/profiles/default/bin/nix-env -p /nix/var/nix/profiles/system --set "$system"
  "$system/activate"
fi

/usr/bin/defaults write /var/db/dotfiles rev -string "$target"
echo "applied $target ($host)"
