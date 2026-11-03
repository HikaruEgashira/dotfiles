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

install_pkg Tailscale io.tailscale.ipn.macsys W5364U7YZB \
  https://pkgs.tailscale.com/stable/Tailscale-1.104.5-macos.pkg \
  f1a2afb589dc16487cff9f23c59d0021a1a4dcf8476d2637ab493c628422b810

if [ ! -d /Applications/Xcode.app ]; then
  /usr/bin/sudo -u hikae -H "$MAS" install 497799835
fi
verify_app /Applications/Xcode.app com.apple.dt.Xcode 59GAB85EFG
