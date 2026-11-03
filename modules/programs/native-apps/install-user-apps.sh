#!/usr/bin/env bash
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$HOME/Applications"

verify_app() {
  local app=$1 bundle=$2 team=$3 details
  /usr/bin/codesign --verify --deep --strict "$app"
  details=$(/usr/bin/codesign -dv --verbose=2 "$app" 2>&1)
  grep -Fqx "Identifier=$bundle" <<<"$details"
  grep -Fqx "TeamIdentifier=$team" <<<"$details"
}

install_app() {
  local name=$1 bundle=$2 team=$3 url=$4 hash=$5 current archive unpack source target
  for current in "/Applications/$name.app" "$HOME/Applications/$name.app"; do
    if [ -d "$current" ]; then
      verify_app "$current" "$bundle" "$team"
      return
    fi
  done

  archive="$work/$name.dmg"
  unpack="$work/$name"
  target="$HOME/Applications/$name.app"
  curl -fsSL --retry 3 "$url" -o "$archive"
  printf '%s  %s\n' "$hash" "$archive" | sha256sum -c -
  mkdir "$unpack"
  (cd "$unpack" && undmg "$archive")
  source="$unpack/$name.app"
  verify_app "$source" "$bundle" "$team"
  /usr/bin/ditto "$source" "$target"
  verify_app "$target" "$bundle" "$team"
}

install_app Discord com.hnc.Discord 53Q6R32WPB \
  https://dl.discordapp.net/apps/osx/0.0.421/Discord.dmg \
  5862c7663124e27284ef513eddf039ee8ae8b6cb6df222afb2779e633f5b5c6a
install_app Slack com.tinyspeck.slackmacgap BQR82RBBHL \
  https://downloads.slack-edge.com/desktop-releases/mac/arm64/4.53.276/Slack-4.53.276-macOS.dmg \
  f2a0a12038b7f3dee5742ce7ceaa29daf38363dec09249f12812c9c0f960328a
install_app Raycast com.raycast.macos SY64MV22J9 \
  'https://x.raycast-releases.com/download?platform=macos&architecture=arm64&version=2.10.1.0' \
  b634cf2b317f16672b781673495dd790b29530095129df5091bba6c3c7bdbbfd
install_app OBS com.obsproject.obs-studio 2MMRE5MTB8 \
  https://cdn-fastly.obsproject.com/downloads/obs-studio-33.0.1-macos-apple.dmg \
  3d6b2eedeb56416602af635adaba32327fdf11ff9d2806a4ce7d5b608de73238
