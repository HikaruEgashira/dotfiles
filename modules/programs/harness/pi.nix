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

  # npm extension は settings.json でバージョン固定しないと起動時に更新通知が出る。
  # pi の更新チェックは npm の min-release-age (~/.npmrc) を見ないため、冷却期間中の版があると
  # 「Package Updates Available」が消えない。固定して通知対象から外す。npm 版の更新は package.json と lock を差し替える手動操作。
  # git extension (ponytail) は sha 固定で upstream の main HEAD を追させない。設定した ref への
  # reset を `pi update --extensions` が行うので、更新は sha を差し替える手動操作だけになる:
  #   git ls-remote https://github.com/DietrichGebert/ponytail HEAD
  # 版は pi-extensions/package.json が正史で、CI が同じ lock で npm audit signatures を通す
  pinnedNpmVersions = (lib.importJSON ./pi-extensions/package.json).dependencies;
  pinnedNpmExtensions = builtins.attrNames pinnedNpmVersions;
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
      lib.concatMapStringsSep " " (pkg: "'${pkg}@${pinnedNpmVersions.${pkg}}'") pinnedNpmExtensions
    } \
      --prefix "${npmRoot}" --save-exact --legacy-peer-deps >/dev/null

    for pkg in ${lib.concatMapStringsSep " " (pkg: "'${pkg}'") pinnedNpmExtensions}; do
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
