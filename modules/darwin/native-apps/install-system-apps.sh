#!/usr/bin/env bash
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

verify_app() {
  local app=$1 bundle=$2 team=$3 details
  /usr/bin/codesign --verify --deep --strict "$app"
  details=$(/usr/bin/codesign -dv --verbose=2 "$app" 2>&1)
  grep -Fqx "Identifier=$bundle" <<<"$details"
  grep -Fqx "TeamIdentifier=$team" <<<"$details"
}

install_pkg() {
  local name=$1 bundle=$2 team=$3 url=$4 hash=$5 archive
  shift 5
  if [ -d "/Applications/$name.app" ]; then
    verify_app "/Applications/$name.app" "$bundle" "$team"
    return
  fi

  archive="$work/$name.pkg"
  curl -fsSL --retry 3 "$url" -o "$archive"
  printf '%s  %s\n' "$hash" "$archive" | sha256sum -c -
  /usr/sbin/pkgutil --check-signature "$archive" | grep -F "($team)"
  /usr/sbin/installer -pkg "$archive" -target / "$@"
  verify_app "/Applications/$name.app" "$bundle" "$team"
}

install_zip() {
  local name=$1 bundle=$2 team=$3 url=$4 hash=$5 archive
  if [ -d "/Applications/$name.app" ]; then
    verify_app "/Applications/$name.app" "$bundle" "$team"
    return
  fi

  archive="$work/$name.zip"
  curl -fsSL --retry 3 "$url" -o "$archive"
  printf '%s  %s\n' "$hash" "$archive" | sha256sum -c -
  /usr/bin/ditto -x -k "$archive" "$work/$name"
  verify_app "$work/$name/$name.app" "$bundle" "$team"
  /usr/sbin/spctl --assess --type execute "$work/$name/$name.app"
  /usr/bin/ditto "$work/$name/$name.app" "/Applications/$name.app"
  /usr/sbin/chown -R hikae:staff "/Applications/$name.app"
}

if [ "${TAILSCALE_GUI:-1}" = 1 ]; then
  install_pkg Tailscale io.tailscale.ipn.macsys W5364U7YZB \
    https://pkgs.tailscale.com/stable/Tailscale-1.104.5-macos.pkg \
    f1a2afb589dc16487cff9f23c59d0021a1a4dcf8476d2637ab493c628422b810
fi

if [ ! -d /Applications/Xcode.app ]; then
  /usr/bin/sudo -u hikae -H "$MAS" install 497799835
fi
verify_app /Applications/Xcode.app com.apple.dt.Xcode 59GAB85EFG

if [ ! -d /Applications/Bitwarden.app ]; then
  /usr/bin/sudo -u hikae -H "$MAS" get 1352778147
fi
verify_app /Applications/Bitwarden.app com.bitwarden.desktop LTZ2PFU5D6

if [ "${ORCA:-0}" = 1 ]; then
  install_zip Orca com.stablyai.orca 6CX3WHS9HZ \
    https://github.com/stablyai/orca/releases/download/v1.4.269/Orca-1.4.269-arm64-mac.zip \
    a6d49b13fb315c55abf68f01937e02262bfa46ce3c8d6d1833c96eebc435070d
fi
