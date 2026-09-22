{
  lib,
  ...
}:

{
  # ALF の受信全拒否で、忘れた dev server の *:PORT bind を LAN から到達不能にする (sudoers 設定: docs/operations.md)
  home.activation.firewall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null 2>&1 \
      && sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on >/dev/null 2>&1 \
      && sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on >/dev/null 2>&1; then
      echo "firewall: global+stealth+blockall applied"
    else
      echo "WARN: firewall posture not applied (one-time setup: docs/operations.md §Firewall)" >&2
    fi
  '';
}
