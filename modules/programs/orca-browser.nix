{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.orcaBrowser;
  bundleId = "dev.egahika.orca-url-handler";
  appDir = "${config.home.homeDirectory}/Applications/Orca URL Handler.app";
  orcaCli = "/Applications/Orca.app/Contents/Resources/bin/orca";
  open-in-orca = pkgs.writeShellScript "open-in-orca" ''
    set -euo pipefail
    # CLI の "active" は cwd 基準なので、GUI で選択中 (無ければ最後に触った) worktree を明示する
    wt=$(${orcaCli} worktree ps --json | ${pkgs.jq}/bin/jq -er \
      '.result.worktrees | (map(select(.isActive)) + sort_by(-.lastActivityAt))[0].worktreeId')
    case $wt in folder:*) sel=$wt ;; *) sel="id:$wt" ;; esac
    ${orcaCli} tab create --worktree "$sel" --url "$1" >/dev/null
  '';
  # Orca.app は http/https を宣言しないため、URL を受けて内蔵ブラウザに渡す
  script = pkgs.writeText "orca-url-handler.applescript" ''
    on open location theURL
      try
        do shell script "${open-in-orca} " & quoted form of theURL & " 2>&1"
        tell application id "com.stablyai.orca" to activate
      on error errMsg
        do shell script "/bin/echo " & quoted form of errMsg & " >> ${config.home.homeDirectory}/Library/Logs/orca-url-handler.log"
        do shell script "/usr/bin/open -b ${cfg.fallbackBundleId} " & quoted form of theURL
      end try
    end open location
  '';
  urlTypes = builtins.toJSON [
    {
      CFBundleURLName = "Web URL";
      CFBundleURLSchemes = [
        "http"
        "https"
      ];
    }
  ];
in
{
  options.dotfiles.orcaBrowser = {
    enable = lib.mkEnableOption "routing http/https links to Orca's embedded browser";
    fallbackBundleId = lib.mkOption {
      type = lib.types.str;
      default = "com.apple.Safari";
      description = "Browser used when the Orca runtime is unreachable.";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.activation.orcaUrlHandler = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      app=${lib.escapeShellArg appDir}
      stamp="$app/Contents/Resources/.source"
      if [ "$(cat "$stamp" 2>/dev/null)" != ${script} ]; then
        run rm -rf "$app"
        run mkdir -p "$(dirname "$app")"
        run /usr/bin/osacompile -o "$app" ${script}
        plist="$app/Contents/Info.plist"
        run /usr/bin/plutil -replace CFBundleIdentifier -string ${bundleId} "$plist"
        run /usr/bin/plutil -replace LSUIElement -bool true "$plist"
        run /usr/bin/plutil -replace CFBundleURLTypes -json ${lib.escapeShellArg urlTypes} "$plist"
        echo ${script} > "$stamp"
        run /usr/bin/codesign --force --deep --sign - "$app"
        run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
      fi
      for scheme in http https; do
        if [ "$(${pkgs.duti}/bin/duti -d "$scheme")" != ${bundleId} ]; then
          run ${pkgs.duti}/bin/duti -s ${bundleId} "$scheme"
        fi
      done
    '';
  };
}
