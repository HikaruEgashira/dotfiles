#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/check-launchd-labels.sh"
known=$'dev.egahika.ssh-agent\ndev.egahika.ssh-add\ncom.anthropic.claudefordesktop.ShipIt\nus.zoom.updater\nus.zoom.updater.login.check'
printf '%s\n' "$known" 'com.stablyai.orca.terminal.5bac8c2f68c5fd54.v51' 'dev.herdr.server.4516.1792732273012851000' | bash "$checker" "$known"
for label in net.tunnelblick.launcher dev.herdr.server dev.herdr.server. dev.herdr.serverx.123 com.stablyai.orca.terminalx.123 us.zoom.unexpected; do
  if output=$(printf '%s\n' "$label" | bash "$checker" "$known" 2>&1); then
    printf 'FAIL: unexpected label accepted: %s\n' "$label" >&2
    exit 1
  fi
  [[ $output == *"UNKNOWN  $label"* ]]
done
printf '%s\n' 'ok: exact labels and tool instances accepted; retired and unrelated labels rejected'
