{
  lib,
  ...
}:

{
  # ALF の非必須受信を遮断し、忘れた dev server の *:PORT bind を LAN から通常到達不能にする (sudoers 設定: docs/operations.md)
  home.activation.firewall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setter_failed=0
    run --silence /usr/bin/sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on || setter_failed=1
    run --silence /usr/bin/sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on || setter_failed=1
    run --silence /usr/bin/sudo -n /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on || setter_failed=1
    if (( setter_failed != 0 )); then
      echo "ERROR: firewall posture could not be applied" >&2
      exit 1
    fi
    if [ -n "''${DRY_RUN:-}" ]; then
      echo "firewall: dry-run (global+stealth+blockall queued)"
    else
      if ! actual=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode --getblockall 2>&1); then
        echo "ERROR: firewall posture could not be read back" >&2
        exit 1
      fi
      if [[ "$actual" == *"(State = 1)"* || "$actual" == *"(State = 2)"* ]] &&
        [[ "$actual" == *"stealth mode is on"* ]] &&
        [[ "$actual" == *"blocking all non-essential incoming connections"* ]]; then
        echo "firewall: global+stealth+blockall applied"
      else
        echo "ERROR: firewall posture verification failed" >&2
        echo "$actual" >&2
        exit 1
      fi
    fi
  '';
}
