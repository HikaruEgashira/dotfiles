{
  config,
  lib,
  pkgs,
  ...
}:
let
  # opencode loads only the first existing global instruction file, so merge ponytail into it.
  content = builtins.readFile ./AGENTS.md + "\n" + builtins.readFile ./opencode/ponytail.md;
  preflight = builtins.readFile ./opencode/preflight.sh;
  # 版は aqua.yaml の pin が正史なので、自己更新で検証外の binary に置き換わらないようにする
  noAutoupdate.OPENCODE_DISABLE_AUTOUPDATE = "1";
in
{
  home = {
    sessionVariables = noAutoupdate;
    file.".config/opencode/AGENTS.md" = {
      text = content;
      force = true;
    };
    # script 起動や launchd からも同じ preflight を使えるように executable として置く
    file.".local/bin/opencode-health" = {
      text = preflight;
      executable = true;
    };
  };

  programs.zsh.initContent = lib.mkAfter preflight;

  launchd.agents.opencode-service-health = {
    enable = true;
    config = {
      Label = "dev.egahika.opencode-service-health";
      ProgramArguments = [ "${config.home.homeDirectory}/.local/bin/opencode-health" ];
      StartCalendarInterval = [
        {
          Hour = 9;
          Minute = 5;
        }
      ];
      RunAtLoad = false;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${config.xdg.dataHome}/aquaproj-aqua/bin:${pkgs.aqua}/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      }
      // noAutoupdate
      // lib.filterAttrs (k: _: lib.hasPrefix "AQUA_" k) config.home.sessionVariables;
      StandardOutPath = "${config.home.homeDirectory}/.cache/opencode-service-health.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/opencode-service-health.err";
    };
  };
}
