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

  # pi は更新チェックで npm の min-release-age (~/.npmrc) を見ないため、冷却期間中の版があると
  # 起動のたびに「Package Updates Available」を出す。pi-subagents は settings.json で
  # バージョン固定にして通知対象から外し、固定先をこのジョブが日次で進める。
  extensionsUpdate = pkgs.writeShellScript "pi-extensions-update" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:${home}/.nix-profile/bin:${home}/.local/share/mise/shims:/usr/bin:/bin:/usr/sbin:/sbin

    # 未ピンの extension (git パッケージや prompt-enhancer) は pi 自身に更新させる
    pi update --extensions

    # "latest" の解決は npm の min-release-age に従うので、冷却期間を終えた版だけが入る
    npm install pi-subagents@latest --prefix "${npmRoot}" --legacy-peer-deps >/dev/null

    version=$(jq -r .version "${npmRoot}/node_modules/pi-subagents/package.json")
    tmp=$(mktemp)
    jq --arg pin "npm:pi-subagents@$version" \
      '.packages |= map(if type == "string" and (startswith("npm:pi-subagents@") or . == "npm:pi-subagents") then $pin else . end)' \
      "${settingsPath}" >"$tmp"
    mv "$tmp" "${settingsPath}"
    echo "pi-subagents pinned to $version"
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
