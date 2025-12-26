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
    };
  };
}
