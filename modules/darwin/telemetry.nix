# GUI 起動でシェル環境を継承しないアプリの telemetry を、ユーザー設定より強い層で止める
{ lib, ... }:
{
  environment.etc."codex/managed_config.toml".source = ../programs/codex/managed_config.toml;

  system.defaults.CustomUserPreferences."com.google.Chrome" = {
    MetricsReportingEnabled = false;
    UrlKeyedAnonymizedDataCollectionEnabled = false;
    FeedbackSurveysEnabled = false;
  };

  # 「Mac 解析を共有」「App デベロッパと共有」は system 全体の plist にしか無い
  system.activationScripts.postActivation.text = lib.mkAfter ''
    plist="/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist"
    /usr/bin/defaults write "$plist" AutoSubmit -bool false
    /usr/bin/defaults write "$plist" ThirdPartyDataSubmit -bool false
  '';
}
