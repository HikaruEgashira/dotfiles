{ pkgs, ... }:

{
  programs.home-manager.enable = true;
  services.lorri.enable = true;

  home.username = "egahika";
  home.homeDirectory = "/home/egahika";
  home.stateVersion = "21.11";
  home.packages = with pkgs; [ ghq ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.direnv.nix-direnv.enableFlakes = true;

  programs.git = {
    enable = true;
    userName = "hikae";
    userEmail = "contact@egahika.dev";
    extraConfig = {
      core = {
        whitespace = "trailing-space,space-before-tab";
        editor = "code --wait";
      };
    };
  };
  programs.fzf.enable = true;
  programs.lsd.enable = true;
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    shellAliases =
    {
      c = "code .";
      rel = "source ~/.zshrc";
      ls = "lsd";
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
export PATH=$HOME/.docker/cli-plugins:$PATH # Rancher desktop
export NODE_OPTIONS=--max_old_space_size=8192
export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).
    '';
  };
}
