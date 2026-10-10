#!/usr/bin/env bash
# launchd-cleanup.sh — remove the dead/duplicate launchd jobs tracked in docs/launchd.md.
# Run as your normal user; sudo is invoked only for the root-owned steps. Idempotent.
set -euo pipefail

say() { printf '\n==> %s\n' "$1"; }

# --- WARP: full removal via the vendor uninstaller (kills processes, tears down
#     the network/system extension, deletes the app, keys, logs, prefs) ----------
if [ -d "/Applications/Cloudflare WARP.app" ]; then
  say "WARP: vendor uninstaller"
  sudo "/Applications/Cloudflare WARP.app/Contents/Resources/uninstall.sh" -f
fi
# WARP can leave a login item behind.
osascript -e 'tell application "System Events" to delete login item "Cloudflare WARP"' 2>/dev/null || true

# --- Google keystone: empty plists replaced by com.google.GoogleUpdater.wake ---
say "Google keystone: removing empty plists"
sudo rm -f /Library/LaunchAgents/com.google.keystone.agent.plist \
  /Library/LaunchAgents/com.google.keystone.xpcservice.plist
sudo rm -rf /Library/Google/GoogleSoftwareUpdate

# --- cloudflared daemon: broken (token file absent); the CLI stays nix-owned ---
say "cloudflared: removing broken system daemon"
sudo launchctl bootout system/com.cloudflare.cloudflared 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
sudo rm -rf "/Library/Application Support/com.cloudflare.cloudflared"

# --- Tunnelblick: no VPN profiles; openvpn is nix-managed ----------------------
say "Tunnelblick: removing cask + daemon"
brew uninstall --cask tunnelblick 2>/dev/null || true
sudo launchctl bootout system/net.tunnelblick.tunnelblick.tunnelblickd 2>/dev/null || true
sudo launchctl bootout "gui/$(id -u)/net.tunnelblick.launcher" 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/net.tunnelblick.tunnelblick.tunnelblickd.plist
sudo rm -rf "/Library/Application Support/Tunnelblick"

# --- untracked brew formulae superseded by nix --------------------------------
say "brew: removing watchman/cloudflared (superseded by nix)"
brew uninstall --formula watchman 2>/dev/null || true
brew uninstall --formula cloudflared 2>/dev/null || true

# --- WARP support dir (updater may recreate it) -------------------------------
sudo rm -rf "/Library/Application Support/Cloudflare"

say "done — verify with: nix run ~/dotfiles#launchd-audit"
