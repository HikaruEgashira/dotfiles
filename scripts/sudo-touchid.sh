#!/usr/bin/env bash
set -euo pipefail

PAM_SUDO_LOCAL=${PAM_SUDO_LOCAL:-/etc/pam.d/sudo_local}
PAM_SUDO=${PAM_SUDO:-/etc/pam.d/sudo}
PAM_TID_LINE='auth       sufficient     pam_tid.so'

usage() {
  cat <<'EOF'
Usage: sudo-touchid.sh [enable|disable|status]

Manages Touch ID for sudo via /etc/pam.d/sudo_local (macOS Ventura+).
EOF
}

write_root_owned() {
  sudo install -o root -g wheel -m 0644 "$1" "$2"
}

# The pre-sudo_local script inserted the line into /etc/pam.d/sudo directly.
strip_tid_line() {
  local file=$1 tmp
  [ -f "$file" ] || return 0
  grep -Fqx "$PAM_TID_LINE" "$file" || return 0
  tmp=$(mktemp)
  grep -Fvx "$PAM_TID_LINE" "$file" >"$tmp" || true
  write_root_owned "$tmp" "$file"
  rm -f "$tmp"
}

status() {
  if grep -Fqx "$PAM_TID_LINE" "$PAM_SUDO_LOCAL" 2>/dev/null; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

enable() {
  printf '%s\n' "$PAM_TID_LINE" | sudo tee "$PAM_SUDO_LOCAL" >/dev/null
  strip_tid_line "$PAM_SUDO"
  echo "Enabled Touch ID for sudo."
}

disable() {
  strip_tid_line "$PAM_SUDO_LOCAL"
  strip_tid_line "$PAM_SUDO"
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
