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
  # git パッケージ (ponytail) は cooldown の対象外なので pi に任せる。
  pinnedNpmExtensions = [
    "@hikae/pi-prompt-enhancer"
    "pi-subagents"
  ];
  extensionsUpdate = pkgs.writeShellScript "pi-extensions-update" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:${home}/.nix-profile/bin:${home}/.local/share/mise/shims:/usr/bin:/bin:/usr/sbin:/sbin

    # git パッケージは pi 自身に更新させる
    pi update --extensions

    # "latest" の解決は npm の min-release-age に従うので、冷却期間を終えた版だけが入る
    npm install ${lib.concatMapStringsSep " " (pkg: "'${pkg}@latest'") pinnedNpmExtensions} \
      --prefix "${npmRoot}" --legacy-peer-deps >/dev/null

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
(import ../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Pi" [
  {
    rel = ".pi/agent/APPEND_SYSTEM.md";
    source = ./claude/CLAUDE.md;
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
