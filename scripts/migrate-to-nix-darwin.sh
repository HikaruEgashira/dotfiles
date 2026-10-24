#!/usr/bin/env bash
# Determinate Nix から nix-darwin 管理の upstream Nix へ移行する。
# 冪等: 途中で失敗しても再実行で続きから進む。退避物はすべて $backup に残る。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

say() { printf '==> %s\n' "$*" >&2; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || die "macOS only"
[ "$(id -u)" -ne 0 ] || die "root ではなく primary user で実行する"

say "building darwin system"
system_path=$(nix build --no-link --print-out-paths "$root#darwinConfigurations.hikae.system")
etc_dir=$(readlink -f "$system_path/etc")

backup=/var/backups/nix-darwin-migration/$(date -u +%Y%m%dT%H%M%SZ)

say "requesting sudo"
sudo -v
(
  while sleep 30; do
    sudo -n true 2>/dev/null || exit
    kill -0 "$$" 2>/dev/null || exit
  done
) &
keepalive=$!
trap 'kill "$keepalive" 2>/dev/null || true' EXIT

sudo mkdir -p "$backup"

# 1. nix-darwin が持つ /etc の leaf file と衝突する実ファイルを退避する
#    (activation は未知の中身を上書きせず abort する)
say "moving conflicting /etc files to $backup"
while IFS= read -r rel; do
  target="/etc/$rel"
  [ -f "$target" ] || continue
  [ -L "$target" ] && continue
  sudo mkdir -p "$backup/etc/$(dirname "$rel")"
  sudo mv "$target" "$backup/etc/$rel"
  echo "  /etc/$rel"
done < <(
  cd "$etc_dir"
  find . -type l | sed 's|^\./||' | sort
)

# 2. DetSys 固有で built tree に無い設定も退避する (extra-trusted-users は nix.settings が引き取る)
if [ -f /etc/nix/nix.custom.conf ]; then
  sudo mkdir -p "$backup/etc/nix"
  sudo mv /etc/nix/nix.custom.conf "$backup/etc/nix/nix.custom.conf"
  echo "  /etc/nix/nix.custom.conf"
fi

# 3. 世代を記録する (darwin-rebuild switch が行うのと同じ操作。daemon 停止前に済ませる)
say "recording the system generation"
sudo /nix/var/nix/profiles/default/bin/nix-env \
  -p /nix/var/nix/profiles/system \
  --set "$system_path"

# 4. Determinate Nix の daemon を外す。store の mount は /etc/fstab の LABEL 行に任せる
say "unloading Determinate Nix launch daemons"
for label in \
  systems.determinate.nix-daemon \
  systems.determinate.nix-installer.nix-hook \
  systems.determinate.nix-store; do
  plist="/Library/LaunchDaemons/$label.plist"
  [ -f "$plist" ] || continue
  sudo launchctl bootout "system/$label" 2>/dev/null || true
  sudo cp -a "$plist" "$backup/"
  sudo rm -f "$plist"
  echo "  $label"
done

sudo pkill -f '/usr/local/bin/determinate-nixd' 2>/dev/null || true
sudo pkill -f '/nix/var/nix/profiles/default/bin/nix-daemon' 2>/dev/null || true

# upstream の nix-daemon は /nix/var/nix/daemon-socket/socket を直接 bind する
sudo rm -f /nix/var/nix/daemon-socket/socket

# 5. 起動時の /nix mount は fstab の LABEL 行が担う。DetSys の noauto 行だけ落とす
if grep -q 'Added by the Determinate Nix Installer' /etc/fstab; then
  say "dropping the Determinate fstab entry"
  sudo cp -a /etc/fstab "$backup/fstab"
  sudo sed -i '' '/Added by the Determinate Nix Installer/d' /etc/fstab
fi
grep -q '^LABEL=Nix\\ Store' /etc/fstab ||
  die '/etc/fstab に LABEL=Nix\ Store 行が無い。再起動後に /nix が mount されないので中止する'

# 6. activation (root)。ここで upstream nix-daemon が起動し /etc/nix/nix.conf が置き換わる
say "activating"
sudo "$system_path/activate"

# 7. firewall 用に手書きしていた NOPASSWD は root activation に置き換わったので撤去する
if [ -f /etc/sudoers.d/firewall ]; then
  sudo cp -a /etc/sudoers.d/firewall "$backup/"
  sudo rm -f /etc/sudoers.d/firewall
  echo "  removed /etc/sudoers.d/firewall"
fi

say "verifying"
nix --version
launchctl print system/org.nixos.nix-daemon >/dev/null && echo "  nix-daemon: loaded"
nix store ping >/dev/null && echo "  store: reachable"
[ -L /run/current-system ] && echo "  current-system: $(readlink /run/current-system)"

say "done — backup: $backup"
echo
echo "次の再起動で /nix が自動 mount されることを確認する:"
echo "  mount | grep ' /nix '"
echo "/nix が空だった場合は backup の plist を戻して再起動する:"
echo "  sudo cp $backup/systems.determinate.nix-store.plist /Library/LaunchDaemons/ && sudo launchctl load -w /Library/LaunchDaemons/systems.determinate.nix-store.plist"
