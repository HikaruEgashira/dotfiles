# managed settings はユーザーの settings.json より優先され、Claude Code やツールの書き込みで消えない
{ lib, pkgs, ... }:

let
  # Claude Code の telemetry は手元の collector に送る。token と再送は
  # modules/programs/claude-otel.nix が持つ
  managedSettings = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON {
      env = {
        CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
        CLAUDE_CODE_ENABLE_TELEMETRY = "1";
        DISABLE_TELEMETRY = "1";
        DISABLE_ERROR_REPORTING = "1";
        OTEL_METRICS_EXPORTER = "otlp";
        OTEL_LOGS_EXPORTER = "otlp";
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/json";
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:4318";
        OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE = "delta";
        OTEL_METRIC_EXPORT_INTERVAL = "10000";
      };
      syncClaudeAiSkills = false;
      language = "japanese";
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
