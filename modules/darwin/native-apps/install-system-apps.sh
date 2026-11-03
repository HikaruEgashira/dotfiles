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

cat >"$work/windows-app-choices.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><dict>
  <key>choiceAttribute</key><string>selected</string>
  <key>attributeSetting</key><integer>0</integer>
  <key>choiceIdentifier</key><string>com.microsoft.autoupdate</string>
</dict></array></plist>
XML
install_pkg 'Windows App' com.microsoft.rdc.macos UBF8T346G9 \
  https://res.public.onecdn.static.microsoft/mro1cdnstorage/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Windows_App_11.4.4_installer.pkg \
  70041210ec1c40cbcc1913010fb9a7de7e2b0c8d9f336777775789ae65bc9cab \
  -applyChoiceChangesXML "$work/windows-app-choices.xml"

if [ ! -d /Applications/Xcode.app ]; then
  /usr/bin/sudo -u hikae -H "$MAS" install 497799835
fi
verify_app /Applications/Xcode.app com.apple.dt.Xcode 59GAB85EFG
