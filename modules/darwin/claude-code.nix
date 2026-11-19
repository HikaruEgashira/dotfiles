# managed settings はユーザーの settings.json より優先され、Claude Code やツールの書き込みで消えない
{ lib, pkgs, ... }:

let
  # Claude Code の telemetry を gh-intel.com の collector に送る
  # (sisaku-security/gh-intel.com docs/operations/connect-otel.md)。
  # Access の token を cloudflared から取り、cf-access-token header で渡す。
  # token が無いか切れたときだけブラウザでログインする。
  otelEndpoint = "https://otel.gh-intel.com";
  otelHeadersHelper = pkgs.writeShellScript "claude-otel-headers" ''
    set -euo pipefail
    cf=${lib.getExe pkgs.cloudflared}
    token=$("$cf" access token -app=${otelEndpoint} 2>/dev/null) || token=""
    if [[ -z $token || $token == *Unable* ]]; then
      "$cf" access login --quiet ${otelEndpoint} >/dev/null 2>&1
      token=$("$cf" access token -app=${otelEndpoint})
    fi
    printf '{"cf-access-token":"%s"}\n' "$token"
  '';

  managedSettings = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON {
      env = {
        CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
        CLAUDE_CODE_ENABLE_TELEMETRY = "1";
        OTEL_METRICS_EXPORTER = "otlp";
        OTEL_LOGS_EXPORTER = "otlp";
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/json";
        OTEL_EXPORTER_OTLP_ENDPOINT = otelEndpoint;
        OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE = "delta";
        OTEL_METRIC_EXPORT_INTERVAL = "10000";
      };
      otelHeadersHelper = "${otelHeadersHelper}";
      syncClaudeAiSkills = false;
    }
  );
  dir = "/Library/Application Support/ClaudeCode";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    install -d -m 755 -o root -g wheel "${dir}"
    install -m 644 -o root -g wheel ${managedSettings} "${dir}/managed-settings.json"
  '';
}
