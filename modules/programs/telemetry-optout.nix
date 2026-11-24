# 既定で外部に利用統計や crash report を送る CLI を、ログインシェル経由で起動する全プロセスで止める
{
  config,
  lib,
  pkgs,
  ...
}:
let
  scan = pkgs.writeShellScript "telemetry-audit-bg" ''
    log="${config.xdg.stateHome}/telemetry-audit.log"
    mkdir -p "$(dirname "$log")"
    if ! ${pkgs.python3}/bin/python3 -I ${../../scripts/telemetry-scan.py} ${../../lib/telemetry-ledger.json} \
      "$HOME/.nix-profile/bin" "$HOME/.local/share/aquaproj-aqua/pkgs" /Applications "$HOME/Applications" >"$log" 2>&1; then
      if [ -x /usr/bin/osascript ]; then
        /usr/bin/osascript -e 'display notification "未分類の telemetry を検出: ${config.xdg.stateHome}/telemetry-audit.log" with title "telemetry-audit"'
      fi
    fi
  '';
in
{
  home = {
    sessionVariables = {
      DO_NOT_TRACK = "1";
      CHECKPOINT_DISABLE = "1";
      CLOUDSDK_CORE_DISABLE_USAGE_REPORTING = "true";
      HF_HUB_DISABLE_TELEMETRY = "1";
      POWERSHELL_TELEMETRY_OPTOUT = "1";
      GRAPHITE_DISABLE_TELEMETRY = "1";
      HIGGSFIELD_DISABLE_TELEMETRY = "1";
      PI_TELEMETRY = "0";
      FLY_SEND_METRICS = "0";
      PLENO_DLP_CRASH_REPORTS = "0";
      GH_TELEMETRY = "false";
      CLERK_TELEMETRY_DISABLED = "1";
    };

    # GOTELEMETRY は読み取り専用で、mode は go telemetry が書く設定ファイルにしか無い
    activation.goTelemetryOff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ "$(${pkgs.go}/bin/go telemetry)" != "off" ]; then
        $DRY_RUN_CMD ${pkgs.go}/bin/go telemetry off
      fi
    '';

    # 新しく入った tool の telemetry を台帳と突き合わせる。走査は数分かかるので activation を待たせない
    activation.telemetryAudit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN_CMD:-}" ]; then
        ${pkgs.coreutils}/bin/nohup ${scan} >/dev/null 2>&1 &
      fi
    '';
  };
}
