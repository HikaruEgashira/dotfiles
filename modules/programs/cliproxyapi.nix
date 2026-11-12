{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/share/cliproxyapi";
  port = 8317;
  hub = config.programs.cliproxyapi.hub.enable;
  json = pkgs.formats.json { };

  compat = name: baseUrl: keyVar: models: {
    inherit name;
    prefix = name;
    base-url = baseUrl;
    keys = [ (lib.setAttrByPath [ "api-key" ] "@${keyVar}@") ];
    models = map (m: if builtins.isString m then { name = m; } else m) models;
  };

  # 秘密は @NAME@ のまま store に置き、起動時に vault の値を埋めた runtime copy を 0600 で書く
  template = json.generate "cliproxyapi-config.json" {
    config-version = 8;
    server = {
      host = "127.0.0.1";
      inherit port;
    };
    # 空の secret-key で management API を無効化し、config の書き戻しも起こさない
    management = {
      allow-remote = false;
      secret-key = "";
      disable-control-panel = true;
    };
    access.api-keys = [ "@CLIPROXYAPI_CLIENT_KEY@" ];
    oauth.auth-dir = "${stateDir}/auths";
    # catalog-sync が ChatGPT の実 model 一覧で補った local catalog。CPA は変更を検知して再読込する
    models = {
      catalog = "${stateDir}/models-catalog.json";
      codex-catalog = "${stateDir}/codex-catalog.json";
    };
    routing = {
      session-affinity = true;
      # 接頭辞なしの名前 (gpt-6-luna 等) を ChatGPT OAuth に固定し、他 provider の同名 model へ流さない
      force-model-prefix = true;
    };
    observability.usage.usage-statistics-enabled = false;
    api-keys.openai-compatibility = [
      (compat "Aparture" "https://ai.tailc30b81.ts.net/v1" "APARTURE_API_KEY" [
        "deepseek-v4-1-flash"
        "glm-5-3-flash"
        {
          name = "accounts/fireworks/routers/glm-5p3-fast";
          alias = "accounts-fireworks-routers-glm-5p3-fast";
        }
        {
          name = "accounts/fireworks/routers/deepseek-flash-latest";
          alias = "accounts-fireworks-routers-deepseek-flash-latest";
        }
        {
          name = "accounts/fireworks/routers/glm-flash-latest";
          alias = "accounts-fireworks-routers-glm-flash-latest";
        }
      ])
    ]
    ++ lib.optionals hub [
      (compat "Strata" "http://127.0.0.1:8080/v1" "STRATA_API_KEY" [
        "qwen3.8-flash-next-unsloth-ud-q6_k_xl"
      ])
    ];
  };

  catalogSync = pkgs.writeShellScript "cliproxyapi-catalog-sync" ''
    exec ${lib.getExe pkgs.python3} -I ${./cliproxyapi/catalog-sync.py} ${stateDir} "$@"
  '';

  run = pkgs.writeShellScript "cliproxyapi-run" ''
    set -eu
    umask 077
    ${pkgs.coreutils}/bin/install -d -m 0700 ${stateDir}/auths
    export PATH=${
      lib.makeBinPath [
        pkgs.age
        pkgs.age-plugin-se
      ]
    }:$PATH
    ${lib.getExe pkgs.python3} -I ${./cliproxyapi/render-config.py} ${template} ${stateDir} ${home}/.config/secrets
    # ChatGPT の access token は寿命 (~46h) が CPA の既定 refresh lead (96h) より短く、毎 tick refresh して token を rotate し続けるため間隔を固定する
    for f in ${stateDir}/auths/codex-*.json; do
      [ -e "$f" ] || continue
      ${lib.getExe pkgs.jq} -e 'has("refresh_interval_seconds")' "$f" >/dev/null && continue
      ${lib.getExe pkgs.jq} '.refresh_interval_seconds = 28800' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    done
    ${catalogSync} || true
    exec ${lib.getExe pkgs.cliproxyapi} -config ${stateDir}/config.yaml
  '';
in
{
  options.programs.cliproxyapi.hub.enable = lib.mkEnableOption "Mac Studio Strata and Tailscale hub";

  config.launchd.agents = {
    cliproxyapi = {
      enable = true;
      config = {
        Label = "dev.egahika.cliproxyapi";
        ProgramArguments = [ "${run}" ];
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = stateDir;
        StandardOutPath = "${stateDir}/service.log";
        StandardErrorPath = "${stateDir}/service.log";
      };
    };

    # 起動時の sync は proxy 起動前なので Codex 向け catalog の書き出しはこちらが担う
    cliproxyapi-catalog-sync = {
      enable = true;
      config = {
        Label = "dev.egahika.cliproxyapi-catalog-sync";
        ProgramArguments = [
          "${catalogSync}"
          "${home}/.codex/cliproxyapi-catalog.json"
        ];
        RunAtLoad = true;
        StartInterval = 3 * 60 * 60;
        StandardOutPath = "${stateDir}/catalog-sync.log";
        StandardErrorPath = "${stateDir}/catalog-sync.log";
      };
    };
    cliproxyapi-serve = lib.mkIf hub {
      enable = true;
      config = {
        Label = "dev.egahika.cliproxyapi-serve";
        ProgramArguments = [
          "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
          "serve"
          "--bg"
          "--https=8317"
          "http://127.0.0.1:8317"
        ];
        RunAtLoad = true;
        StartInterval = 300;
        # アプリ内 CLI は TERM がないと GUI 起動と判定する
        EnvironmentVariables = {
          TERM = "dumb";
          HOME = home;
        };
        StandardOutPath = "${stateDir}/serve.log";
        StandardErrorPath = "${stateDir}/serve.log";
      };
    };

    cliproxyapi-awake = lib.mkIf hub {
      enable = true;
      config = {
        Label = "dev.egahika.cliproxyapi-awake";
        ProgramArguments = [
          "/usr/bin/caffeinate"
          "-s"
        ];
        RunAtLoad = true;
        KeepAlive = true;
      };
    };
  };
}
