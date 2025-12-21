{ pkgs, ... }:

{
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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
      enableZshIntegration = true;
    };

    aria2.enable = true;

    starship = {
      enable = true;
      # Additional starship configuration can go here
      # settings = builtins.fromTOML (builtins.readFile ../configs/starship.toml);
    };
  };
}
