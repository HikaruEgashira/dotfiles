{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.username = "egahika";
  home.homeDirectory = "/home/egahika";
  home.stateVersion = "21.11";
  home.packages = with pkgs; [ lsd fd bat ghq fzf starship ];

  programs.git = {
    enable = true;
    userName = "HikaruEgashira";
    userEmail = "s1811320@gmail.com";
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
    enableSyntaxHighlighting = true;
    dotDir = ".config/zsh";
    shellAliases =
    {
      c = "code .";
      rel = "source ~/.zshrc";
      ls = "lsd";
      fd = "fdfind";
      cat = "bat";
    };
    initExtra = ''
function fzf-src () {
  local selected_dir=$(ghq list -p | fzf --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ''${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N fzf-src
bindkey '^g' fzf-src
source $HOME/.nix-profile/etc/profile.d/nix.sh
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels''${NIX_PATH:+:$NIX_PATH}
    '';
  };
}
