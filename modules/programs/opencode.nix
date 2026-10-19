{
  config,
  lib,
  ...
}:
let
  # opencode loads only the first existing global instruction file, so merge ponytail into it.
  content = builtins.readFile ./claude/CLAUDE.md + "\n" + builtins.readFile ./opencode/ponytail.md;
  preflight = builtins.readFile ./opencode/preflight.sh;
in
{
  home.file.".config/opencode/AGENTS.md" = {
    text = content;
    force = true;
  };

  # opencode は自己更新する binary なので dotfiles からは起動前 preflight だけを差し込む
  programs.zsh.initContent = lib.mkAfter preflight;

  # script 起動や launchd からも同じ preflight を使えるように executable として置く
  home.file.".local/bin/opencode-health" = {
    text = preflight;
    executable = true;
  };

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
        PATH = "${config.home.homeDirectory}/.opencode/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.cache/opencode-service-health.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/opencode-service-health.err";
    };
  };
}
