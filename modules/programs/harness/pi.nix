{
  config,
  pkgs,
  lib,
  ...
}:

let
  home = config.home.homeDirectory;
  settingsPath = "${home}/.pi/agent/settings.json";
  npmRoot = "${home}/.pi/agent/npm";

  # npm extension は pi-extensions.json の固定版だけを入れる (floating な @latest は使わない)。
  # 各版の SLSA provenance は CI の scripts/pi-provenance.sh が検証する。版の更新は json を書き換える PR で行う。
  # settings.json も同じ版へ固定し、pi 起動時の更新通知の対象から外す。
  # git extension (ponytail) は sha 固定で upstream の main HEAD を追させない。設定した ref への
  # reset を `pi update --extensions` が行うので、更新は sha を差し替える手動操作だけになる:
  #   git ls-remote https://github.com/DietrichGebert/ponytail HEAD
  pinnedNpmExtensions = builtins.fromJSON (builtins.readFile ./pi-extensions.json);
  extensionsUpdate = pkgs.writeShellScript "pi-extensions-update" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:${home}/.nix-profile/bin:/usr/bin:/bin:/usr/sbin:/sbin

    # pin 済み git ref をその sha へ reset するだけ（追従はしない）
    pi update --extensions

    npm install ${
      lib.concatMapStringsSep " " (e: "'${e.name}@${e.version}'") pinnedNpmExtensions
    } \
      --prefix "${npmRoot}" --legacy-peer-deps --save-exact >/dev/null

    for pkg in ${lib.concatMapStringsSep " " (e: "'${e.name}'") pinnedNpmExtensions}; do
      version=$(jq -r .version "${npmRoot}/node_modules/$pkg/package.json")
      tmp=$(mktemp)
      jq --arg src "npm:$pkg" --arg pin "npm:$pkg@$version" \
        '.packages |= map(if type == "string" and (. == $src or startswith($src + "@")) then $pin else . end)' \
        "${settingsPath}" >"$tmp"
      mv "$tmp" "${settingsPath}"
      echo "$pkg pinned to $version"
    done
  '';
in
(import ../../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Pi" [
  {
    rel = ".pi/agent/APPEND_SYSTEM.md";
    source = ./AGENTS.md;
  }
]
// {
  launchd.agents.pi-extensions-update = {
    enable = true;
    config = {
      Label = "dev.egahika.pi-extensions-update";
      ProgramArguments = [ "${extensionsUpdate}" ];
      StartCalendarInterval = [
        {
          Hour = 9;
          Minute = 10;
        }
      ];
      RunAtLoad = false;
      StandardOutPath = "${home}/.cache/pi-extensions-update.log";
      StandardErrorPath = "${home}/.cache/pi-extensions-update.err";
    };
  };
}
