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
        format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$character";
        git_branch = {
          symbol = "🌱 ";
          truncation_length = 4;
          truncation_symbol = "";
        };
        git_status = {
          conflicted = "🏳";
          ahead = "🏎💨";
          behind = "😰";
          diverged = "😵";
          untracked = "🤷";
          stashed = "📦";
          modified = "📝";
          staged = "[++\\($count\\)](green)";
          renamed = "👅";
          deleted = "🗑";
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
