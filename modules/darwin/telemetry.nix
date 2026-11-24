# GUI 起動でシェル環境を継承しないアプリの telemetry を、ユーザー設定より強い層で止める
_: {
  environment.etc."codex/managed_config.toml".source = ../programs/codex/managed_config.toml;

  system.defaults.CustomUserPreferences."com.google.Chrome" = {
    MetricsReportingEnabled = false;
    UrlKeyedAnonymizedDataCollectionEnabled = false;
    FeedbackSurveysEnabled = false;
  };
}
