#!/usr/bin/env bash
# Emits a macOS encrypted-DNS (DoH) configuration profile for NextDNS; the profile ID stays out of the public repo.
set -eu

usage() {
  echo "usage: $0 <nextdns-profile-id> [device-name]" >&2
  exit 2
}

profile_id="${1:-}"
[[ $profile_id =~ ^[a-f0-9]{6}$ ]] || usage
device_name="${2:-$(scutil --get LocalHostName)}"
out="${TMPDIR:-/tmp}/nextdns-${profile_id}.mobileconfig"

cat >"$out" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key><string>com.apple.dnsSettings.managed</string>
      <key>PayloadVersion</key><integer>1</integer>
      <key>PayloadIdentifier</key><string>io.nextdns.${profile_id}.dns</string>
      <key>PayloadUUID</key><string>$(uuidgen)</string>
      <key>PayloadDisplayName</key><string>NextDNS DoH</string>
      <key>ProhibitDisablement</key><false/>
      <key>DNSSettings</key>
      <dict>
        <key>DNSProtocol</key><string>HTTPS</string>
        <key>ServerURL</key><string>https://dns.nextdns.io/${profile_id}/${device_name}</string>
      </dict>
    </dict>
  </array>
  <key>PayloadType</key><string>Configuration</string>
  <key>PayloadVersion</key><integer>1</integer>
  <key>PayloadIdentifier</key><string>io.nextdns.${profile_id}</string>
  <key>PayloadUUID</key><string>$(uuidgen)</string>
  <key>PayloadDisplayName</key><string>NextDNS (${profile_id})</string>
  <key>PayloadDescription</key><string>System-wide DNS over HTTPS via NextDNS; bypasses ISP port-53 interception on any network.</string>
  <key>PayloadScope</key><string>System</string>
</dict>
</plist>
PLIST

plutil -lint "$out"
open "$out"
echo "Approve in System Settings > General > Device Management, then verify with: curl -s https://test.nextdns.io"
