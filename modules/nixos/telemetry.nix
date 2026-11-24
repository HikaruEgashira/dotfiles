# ユーザー設定より強い system 層の policy で T3 Code と Codex の telemetry を止める
_: {
  environment.etc = {
    "t3code/policy.json".source = ../programs/t3code/policy.json;
    "codex/managed_config.toml".source = ../programs/codex/managed_config.toml;
  };
}
