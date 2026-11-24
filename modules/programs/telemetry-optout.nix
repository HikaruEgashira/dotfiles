# 既定で外部に利用統計や crash report を送る CLI を、ログインシェル経由で起動する全プロセスで止める
{ lib, pkgs, ... }:
{
  home.sessionVariables = {
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
  };

  # GOTELEMETRY は読み取り専用で、mode は go telemetry が書く設定ファイルにしか無い
  home.activation.goTelemetryOff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ "$(${pkgs.go}/bin/go telemetry)" != "off" ]; then
      $DRY_RUN_CMD ${pkgs.go}/bin/go telemetry off
    fi
  '';
}
