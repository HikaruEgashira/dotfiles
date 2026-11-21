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
  # 「Package Updates Available」が消えない。固定して通知対象から外し、固定先をこのジョブが進める。
  # git extension (ponytail) は sha 固定で upstream の main HEAD を追させない。設定した ref への
  # reset を `pi update --extensions` が行うので、更新は sha を差し替える手動操作だけになる:
  #   git ls-remote https://github.com/DietrichGebert/ponytail HEAD
  # 版の更新はここを書き換える手動操作だけにし、activation で floating install しない
  # pin の正本は CI が lockfile と npm audit signatures で検証する pi-npm/package.json
  pinnedNpmExtensions = (lib.importJSON ./pi-npm/package.json).dependencies;
  npmPkgs = lib.attrNames pinnedNpmExtensions;
  extensionsUpdate = pkgs.writeShellScript "pi-extensions-update" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:${home}/.nix-profile/bin:/usr/bin:/bin:/usr/sbin:/sbin
    # pin は public registry で検証済み (pi-npm/package-lock.json)。継承した NPM_CONFIG_REGISTRY が
    # npm.flatt.tech を指すとトークン失効時に 401 で落ちるため、このジョブは public registry に固定する
    export NPM_CONFIG_REGISTRY=https://registry.npmjs.org/

    # pin 済み git ref をその sha へ reset するだけ（追従はしない）
    pi update --extensions

    npm install ${
      lib.concatStringsSep " " (lib.mapAttrsToList (pkg: v: "'${pkg}@${v}'") pinnedNpmExtensions)
    } \
      --prefix "${npmRoot}" --save-exact --legacy-peer-deps >/dev/null

    for pkg in ${lib.concatMapStringsSep " " (pkg: "'${pkg}'") npmPkgs}; do
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
