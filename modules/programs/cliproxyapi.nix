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
  yaml = pkgs.formats.yaml { };

  compat = name: baseUrl: keyVar: models: {
    inherit name;
    prefix = name;
    base-url = baseUrl;
    keys = [ (lib.setAttrByPath [ "api-key" ] "@${keyVar}@") ];
    models = map (m: if builtins.isString m then { name = m; } else m) models;
  };

  # 秘密は @NAME@ のまま store に置き、起動時に secrets.env の値で置換した runtime copy を 0600 で書く
  template = yaml.generate "cliproxyapi-config.yaml" {
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
    routing.session-affinity = true;
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
      (compat "opencode-go" "https://opencode.ai/zen/go/v1" "OPENCODE_GO_API_KEY" [
        "deepseek-v4-flash"
        "glm-5.3"
        "glm-5.3-flash"
        "gpt-5.6-luna"
        "gpt-6-luna"
        "kimi-k3.1-pro"
        "minimax-m3.1-flash"
        "gemini-4-argon"
        "hy4"
        "step-5-preview"
      ])
    ];
  };

  run = pkgs.writeShellScript "cliproxyapi-run" ''
    set -eu
    . ${./artex/load-env.sh}
    load_env_file ${stateDir}/secrets.env
    : "''${APARTURE_API_KEY:=none}"
    conf=$(<${template})
    for k in CLIPROXYAPI_CLIENT_KEY APARTURE_API_KEY OPENCODE_GO_API_KEY; do
      v=''${!k:?$k is not set in ${stateDir}/secrets.env}
      conf=''${conf//@$k@/$v}
    done
    umask 077
    ${pkgs.coreutils}/bin/install -d -m 0700 ${stateDir}/auths
    printf '%s\n' "$conf" >${stateDir}/config.yaml
    exec ${lib.getExe pkgs.cliproxyapi} -config ${stateDir}/config.yaml
  '';
in
{
  launchd.agents.cliproxyapi = {
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
}
