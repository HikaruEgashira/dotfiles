# Fleet server が tailnet に載った時点で人手なしに登録されるよう、未登録の間だけ定期的に試す
{ pkgs, ... }:

let
  url = "https://fleet.tailc30b81.ts.net";
  enroll = pkgs.writeShellScript "fleet-enroll" ''
    set -eu
    [ -d /opt/orbit ] && exit 0
    work=$(/usr/bin/mktemp -d)
    trap '/bin/rm -rf "$work"' EXIT
    /usr/bin/curl -fsS --max-time 20 ${url}/_bootstrap/enroll-secret -o "$work/secret" || exit 0
    [ -s "$work/secret" ] || exit 0
    cd "$work"
    ${pkgs.fleetctl}/bin/fleetctl package --type pkg --fleet-url ${url} \
      --enroll-secret "$(/bin/cat "$work/secret")" --enable-scripts --outfile "$work/fleetd.pkg"
    /usr/sbin/installer -pkg "$work/fleetd.pkg" -target /
  '';
in
{
  launchd.daemons.fleet-enroll.serviceConfig = {
    ProgramArguments = [ "${enroll}" ];
    RunAtLoad = true;
    StartInterval = 3600;
    StandardOutPath = "/var/log/fleet-enroll.log";
    StandardErrorPath = "/var/log/fleet-enroll.log";
  };
}
