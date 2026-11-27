#!/bin/bash
# Fleet が root で実行する。@TARGET@ は fleet-controller が CI 済みの deploy commit に置き換える
# ~/dotfiles は利用者と AI sandbox が書けるので使わず、target の commit を github: で固定して root が build する
set -euo pipefail

target="@TARGET@"
user=hikae
nix=/nix/var/nix/profiles/default/bin/nix

case "$target" in
*[!0-9a-f]* | "")
  echo "invalid target: $target" >&2
  exit 2
  ;;
esac
[ "${#target}" -eq 40 ] || {
  echo "invalid target: $target" >&2
  exit 2
}

case "$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)" in
Mac-Studio) host=mac-studio home_host=hikae@mac-studio ;;
*) host=hikae home_host=hikae ;;
esac

flake="github:HikaruEgashira/dotfiles/$target"
export NIX_CONFIG="experimental-features = nix-command flakes"
home=$("$nix" build --no-link --print-out-paths "$flake#homeConfigurations.\"$home_host\".activationPackage")
system=$("$nix" build --no-link --print-out-paths "$flake#darwinConfigurations.$host.system")

/usr/bin/sudo -u "$user" -H "$home/activate" >/dev/null
if [ "$(/usr/bin/readlink /run/current-system)" != "$system" ]; then
  "$nix"-env -p /nix/var/nix/profiles/system --set "$system"
  "$system/activate"
fi

/usr/bin/defaults write /var/db/dotfiles rev -string "$target"
echo "applied $target ($host)"
