#!/usr/bin/env bash
# NextDNS DoH profile を生成する。ts.net を DoH から外し、/etc/resolver/ts.net (tailscaled の 100.100.100.100) に MagicDNS を解決させる
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <nextdns-profile-id> <device-name>" >&2
  exit 2
fi
id=$1
device=$2
uuid=$(uuidgen)

cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>DNSSettings</key>
      <dict>
        <key>DNSProtocol</key>
        <string>HTTPS</string>
        <key>ServerURL</key>
        <string>https://apple.dns.nextdns.io/${id}/${device}</string>
      </dict>
      <key>OnDemandRules</key>
      <array>
        <dict>
          <key>Action</key>
          <string>EvaluateConnection</string>
          <key>ActionParameters</key>
          <array>
            <dict>
              <key>DomainAction</key>
              <string>NeverConnect</string>
              <key>Domains</key>
              <array>
                <string>ts.net</string>
                <string>captive.apple.com</string>
              </array>
            </dict>
          </array>
        </dict>
        <dict>
          <key>Action</key>
          <string>Connect</string>
        </dict>
      </array>
      <key>PayloadDisplayName</key>
      <string>NextDNS (${id})</string>
      <key>PayloadIdentifier</key>
      <string>dev.egahika.nextdns.${id}.dnsSettings</string>
      <key>PayloadType</key>
      <string>com.apple.dnsSettings.managed</string>
      <key>PayloadUUID</key>
      <string>$(uuidgen)</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
    </dict>
  </array>
  <key>PayloadDisplayName</key>
  <string>NextDNS (${id})</string>
  <key>PayloadIdentifier</key>
  <string>dev.egahika.nextdns.${id}</string>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>${uuid}</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
EOF
