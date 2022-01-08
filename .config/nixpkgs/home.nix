{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.username = "egahika";
  home.homeDirectory = "/home/egahika";
  home.stateVersion = "21.11";
  home.packages = with pkgs; [ lsd bat ghq fzf starship fd ];

  programs.git = {
    enable = true;
    userName = "HikaruEgashira";
    userEmail = "s1811320@gmail.com";
    coreEditor = "code --wait"
  };
  programs.lsd = {
    enable = true;
  };
  programs.starship = {
    enable = true;
  };
  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    plugins = [
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting.src;
      }
      {
        name = "zsh-completions";
        src = pkgs.zsh-completions.src;
      }
      {
        name = "nix-zsh-completions";
        src = pkgs.nix-zsh-completions.src;
      }
    ];
  };
}
