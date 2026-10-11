{ pkgs, ... }:

{
  programs = {
    fzf = {
      enable = true;
      defaultCommand = "${pkgs.ripgrep}/bin/rg --files --hidden";
      defaultOptions = [
        "--height 40%"
        "--border"
      ];
    };

    bat = {
      enable = true;
      config = {
        theme = "Dracula";
        pager = "less -FR";
      };
    };

    lsd = {
      enable = true;
    };

    aria2.enable = true;

    starship = {
      enable = true;
      settings = {
        # username/hostname render nothing locally; git_state scans git every prompt for a rebase-only indicator
        format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
        git_branch = {
          symbol = "branch ";
          truncation_length = 4;
          truncation_symbol = "";
        };
        git_status = {
          conflicted = "!";
          ahead = "AHEAD ";
          behind = "BEHIND ";
          diverged = "DIVERGED ";
          untracked = "?";
          stashed = "\\$";
          modified = "M";
          staged = "[++\\($count\\)](green)";
          renamed = "R";
          deleted = "D";
        };
        directory = {
          truncation_length = 5;
          truncation_symbol = "…/";
        };
        cmd_duration = {
          min_time = 500;
          format = "underwent [$duration](bold yellow)";
        };
        character = {
          success_symbol = "[❯](purple)";
          error_symbol = "[❯](red)";
          vimcmd_symbol = "[❮](green)";
        };
      };
    };
  };
}
