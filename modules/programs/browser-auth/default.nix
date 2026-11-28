{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.browserAuth;
  home = config.home.homeDirectory;
  stateDir = "${config.xdg.stateHome}/browser-auth";
  approverUrl = "https://${cfg.approverHost}.${cfg.tailnet}:${toString cfg.port}";
  aquaBin = "${config.xdg.dataHome}/aquaproj-aqua/bin";
  python = pkgs.python3.withPackages (ps: [ ps.cryptography ]);
  secretsDir = "${home}/.config/secrets";

  unlock = pkgs.writeShellScript "browser-auth-unlock" ''
    set -euo pipefail
    PATH=${lib.makeBinPath [ pkgs.age-plugin-se ]}:${aquaBin}:$PATH
    ${lib.getExe pkgs.age} -d -i ${secretsDir}/bw-se.txt ${secretsDir}/bw-master.age \
      | bw unlock --raw --passwordfile /dev/stdin
  '';

  matches = lib.concatMap (s: [
    "https://${s}/*"
    "https://*.${s}/*"
  ]) cfg.sites;
  manifest = builtins.toJSON {
    manifest_version = 3;
    name = "Browser Auth Bridge";
    version = "1.0";
    description = "passkey と password を macbook-air の Bitwarden からスマホ承認で受け取る";
    permissions = [ "activeTab" ];
    host_permissions = [ "${approverUrl}/*" ];
    background.service_worker = "background.js";
    action.default_title = "macbook-air の Bitwarden で入力";
    commands.fill = {
      suggested_key.default = "Alt+Shift+L";
      description = "このページにパスワードを入力";
    };
    content_scripts = [
      {
        inherit matches;
        js = [ "inject.js" ];
        world = "MAIN";
        run_at = "document_start";
      }
      {
        inherit matches;
        js = [ "content.js" ];
        run_at = "document_start";
      }
    ];
  };
  extDir = ".local/share/browser-auth/extension";
in
{
  options.dotfiles.browserAuth = {
    sites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "github.com"
        "google.com"
        "cloudflare.com"
      ];
      description = "Registrable domains whose subdomains may receive credentials. Approver and extension both read this list.";
    };
    tailnet = lib.mkOption {
      type = lib.types.str;
      default = "tailc30b81.ts.net";
    };
    approverHost = lib.mkOption {
      type = lib.types.str;
      default = "macbook-air";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8443;
    };
    approver = {
      enable = lib.mkEnableOption "the Bitwarden approver that answers browser requests after phone approval";
      requesters = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "mac-studio" ];
        description = "Untagged tailnet hosts of the same user allowed to request credentials.";
      };
    };
    bridge.enable = lib.mkEnableOption "the Chrome extension that forwards login requests to the approver";
  };

  config = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mkMerge [
      (lib.mkIf cfg.approver.enable {
        launchd.agents.browser-auth-approver = {
          enable = true;
          config = {
            Label = "dev.egahika.browser-auth-approver";
            ProgramArguments = [
              "${python}/bin/python3"
              "-I"
              "${./approver.py}"
              "--listen-port"
              "18443"
              "--base-url"
              approverUrl
              "--state-dir"
              stateDir
              "--tailscale"
              "${pkgs.tailscale}/bin/tailscale"
              "--bw"
              "${aquaBin}/bw"
            ]
            ++ lib.concatMap (s: [
              "--site"
              s
            ]) cfg.sites
            ++ lib.concatMap (r: [
              "--requester"
              r
            ]) cfg.approver.requesters
            ++ [ "${unlock}" ];
            EnvironmentVariables = {
              AQUA_GLOBAL_CONFIG = "${config.xdg.configHome}/aqua/aqua.yaml";
              AQUA_POLICY_CONFIG = "${config.xdg.configHome}/aqua/aqua-policy.yaml";
              AQUA_ENFORCE_CHECKSUM = "true";
              AQUA_ENFORCE_REQUIRE_CHECKSUM = "true";
            };
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "${stateDir}/approver.log";
            StandardErrorPath = "${stateDir}/approver.log";
          };
        };
        launchd.agents.browser-auth-serve = {
          enable = true;
          config = {
            Label = "dev.egahika.browser-auth-serve";
            ProgramArguments = [
              "${pkgs.tailscale}/bin/tailscale"
              "serve"
              "--bg"
              "--https=${toString cfg.port}"
              "http://127.0.0.1:18443"
            ];
            RunAtLoad = true;
            StartInterval = 300;
            StandardOutPath = "${stateDir}/serve.log";
            StandardErrorPath = "${stateDir}/serve.log";
          };
        };
        home.activation.browserAuthStateDir = lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
          run mkdir -p -m 700 ${lib.escapeShellArg stateDir}
        '';
      })
      (lib.mkIf cfg.bridge.enable {
        home.file = {
          "${extDir}/manifest.json".text = manifest;
          "${extDir}/config.js".text = "self.BROWSER_AUTH = ${
            builtins.toJSON { approver = approverUrl; }
          };\n";
          "${extDir}/background.js".source = ./extension/background.js;
          "${extDir}/content.js".source = ./extension/content.js;
          "${extDir}/inject.js".source = ./extension/inject.js;
        };
      })
    ]
  );
}
