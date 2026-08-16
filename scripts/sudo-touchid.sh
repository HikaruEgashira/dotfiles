#!/usr/bin/env bash
set -euo pipefail

PAM_SUDO_FILE=${PAM_SUDO_FILE:-/etc/pam.d/sudo}
PAM_TID_LINE='auth       sufficient     pam_tid.so'
BACKUP_FILE=${BACKUP_FILE:-${PAM_SUDO_FILE}.pre-touchid-backup}

usage() {
  cat <<'EOF'
Usage: sudo-touchid.sh [enable|disable|status]

Safely manage Touch ID for sudo on macOS while preserving root ownership and
0644 permissions on /etc/pam.d/sudo.
EOF
}

require_file() {
  [[ -f $PAM_SUDO_FILE ]] || {
    echo "Missing PAM sudo file: $PAM_SUDO_FILE" >&2
    exit 1
  }
}

status() {
  require_file
  if grep -Fqx "$PAM_TID_LINE" "$PAM_SUDO_FILE"; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

write_root_owned() {
  local src=$1
  sudo install -o root -g wheel -m 0644 "$src" "$PAM_SUDO_FILE"
}

ensure_backup() {
  if [[ ! -f $BACKUP_FILE ]]; then
    sudo cp "$PAM_SUDO_FILE" "$BACKUP_FILE"
    sudo chown root:wheel "$BACKUP_FILE"
    sudo chmod 0644 "$BACKUP_FILE"
  fi
}

enable() {
  require_file
  if grep -Fqx "$PAM_TID_LINE" "$PAM_SUDO_FILE"; then
    echo "Touch ID for sudo is already enabled."
    return 0
  fi

  ensure_backup
  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT

  awk -v line="$PAM_TID_LINE" '
    BEGIN { inserted = 0 }
    /^#/ { print; next }
    !inserted {
      print line
      inserted = 1
    }
    { print }
  ' "$PAM_SUDO_FILE" >"$tmp"

  write_root_owned "$tmp"
  echo "Enabled Touch ID for sudo."
}

disable() {
  require_file
  if ! grep -Fqx "$PAM_TID_LINE" "$PAM_SUDO_FILE"; then
    echo "Touch ID for sudo is already disabled."
    return 0
  fi

  ensure_backup
  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT

  grep -Fvx "$PAM_TID_LINE" "$PAM_SUDO_FILE" >"$tmp"
  write_root_owned "$tmp"
  echo "Disabled Touch ID for sudo."
}

case "${1:-status}" in
enable) enable ;;
disable) disable ;;
status) status ;;
-h | --help | help) usage ;;
*)
  usage >&2
  exit 1
  ;;
esac
