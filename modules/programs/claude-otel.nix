# Claude Code の telemetry を gh-intel.com の collector に欠損なく送る
# (sisaku-security/gh-intel.com docs/operations/connect-otel.md)。
#
# Claude Code は送れなかった telemetry を捨てるので、手元の collector
# (127.0.0.1:4318) に送らせる。collector は送れない batch をディスクの queue に
# 残し、届くまで送り直す。Access の token が切れている間、受け口は 503 を返す
# ので batch は残る。token はファイルに置き、refresh agent が 30 分ごとに
# cloudflared から書き直す。期限の 3 日前からはブラウザでの承認を求める。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  state = "${home}/.local/state/claude-otel";
  app = "https://otel.gh-intel.com";
  cloudflared = lib.getExe pkgs.cloudflared;

  collectorConfig = pkgs.writeText "claude-otel-collector.yaml" (
    builtins.toJSON {
      extensions = {
        file_storage = {
          directory = "${state}/queue";
          create_directory = true;
        };
        bearertokenauth = {
          header = "cf-access-token";
          scheme = "";
          filename = "${state}/token";
        };
      };
      receivers.otlp.protocols.http.endpoint = "127.0.0.1:4318";
      processors.batch = { };
      exporters.otlp_http = {
        endpoint = app;
        encoding = "json";
        auth.authenticator = "bearertokenauth";
        # 503 (token 切れ) と通信断の間は送り直し続け、batch を捨てない
        retry_on_failure = {
          enabled = true;
          max_interval = "5m";
          max_elapsed_time = 0;
        };
        sending_queue = {
          enabled = true;
          storage = "file_storage";
          queue_size = 100000;
        };
      };
      service = {
        extensions = [
          "file_storage"
          "bearertokenauth"
        ];
        pipelines = {
          metrics = {
            receivers = [ "otlp" ];
            processors = [ "batch" ];
            exporters = [ "otlp_http" ];
          };
          logs = {
            receivers = [ "otlp" ];
            processors = [ "batch" ];
            exporters = [ "otlp_http" ];
          };
        };
        telemetry.metrics.level = "none";
      };
    }
  );

  collector = pkgs.writeShellScript "claude-otel-collector" ''
    set -euo pipefail
    umask 077
    mkdir -p ${state}/queue
    # 空のファイルでは bearertokenauth が起動しない。未ログインの間は仮の値で送り、
    # 受け口の 503 で batch を queue に残す
    [ -s ${state}/token ] || printf 'signed-out' > ${state}/token
    exec ${lib.getExe' pkgs.opentelemetry-collector-contrib "otelcol-contrib"} --config ${collectorConfig}
  '';

  refresh = pkgs.writeShellScript "claude-otel-refresh" ''
    set -euo pipefail
    umask 077
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
      ]
    }:/usr/bin:/bin
    mkdir -p ${state}
    exp_of() {
      jq -Rr 'split(".")[1] | gsub("-"; "+") | gsub("_"; "/") | . + ("=" * ((4 - length % 4) % 4)) | @base64d | fromjson | .exp // 0' <<<"$1" 2>/dev/null || echo 0
    }
    token=$(${cloudflared} access token -app=${app} 2>/dev/null) || token=""
    [[ $token == ey* ]] || token=""
    left=$(( $( [ -n "$token" ] && exp_of "$token" || echo 0 ) - $(date +%s) ))
    if (( left < 3 * 86400 )); then
      # 期限が近いか切れている: cache の app token を消して取り直す。org の session
      # が生きていればブラウザなしで新しい token が出る。切れていればブラウザで承認する
      last=$(cat ${state}/last-login 2>/dev/null || echo 0)
      if (( $(date +%s) - last > 6 * 3600 )); then
        date +%s > ${state}/last-login
        /usr/bin/osascript -e 'display notification "ブラウザで Access を承認してください" with title "Claude Code telemetry" subtitle "otel.gh-intel.com の token の期限が近い"' || true
        rm -f ${home}/.cloudflared/otel.gh-intel.com-*-token
        timeout 600 ${cloudflared} access login --quiet ${app} >/dev/null 2>&1 || true
        token=$(${cloudflared} access token -app=${app} 2>/dev/null) || token=""
        [[ $token == ey* ]] || token=""
      fi
    fi
    # 有効な token だけを書く。書き換えは rename で行い、collector が半端な内容を読まない
    if [ -n "$token" ] && [ "$token" != "$(cat ${state}/token 2>/dev/null)" ]; then
      printf '%s' "$token" > ${state}/token.tmp
      mv ${state}/token.tmp ${state}/token
      echo "token refreshed; expires in $(( ($(exp_of "$token") - $(date +%s)) / 3600 ))h"
    fi
  '';
in
{
  launchd.agents.claude-otel-collector = {
    enable = true;
    config = {
      Label = "dev.egahika.claude-otel-collector";
      ProgramArguments = [ "${collector}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${home}/Library/Logs/claude-otel-collector.log";
      StandardErrorPath = "${home}/Library/Logs/claude-otel-collector.log";
    };
  };

  launchd.agents.claude-otel-refresh = {
    enable = true;
    config = {
      Label = "dev.egahika.claude-otel-refresh";
      ProgramArguments = [ "${refresh}" ];
      RunAtLoad = true;
      StartInterval = 30 * 60;
      StandardOutPath = "${home}/Library/Logs/claude-otel-refresh.log";
      StandardErrorPath = "${home}/Library/Logs/claude-otel-refresh.log";
    };
  };
}
