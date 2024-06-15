{ pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "23.11";
  home.packages = with pkgs; [ ghq cachix ripgrep asdf-vm mise ];
  home.enableNixpkgsReleaseCheck = false;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

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
  programs.aria2.enable = true;
  programs.fzf.enable = true;
  programs.bat.enable = true;
  programs.lsd.enable = true;
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    syntaxHighlighting.enable = true;
    shellAliases =
    {
      c = "cursor .";
      rel = "source ~/.zshrc";
      ls = "lsd";
    };
    initExtra = ''
      function fzf-ghq () {
        local selected_dir=$(ghq list -p | fzf --query "$LBUFFER")
        if [ -n "$selected_dir" ]; then
          BUFFER="cd ''${selected_dir}"
          zle accept-line
        fi
        zle clear-screen
      }
      zle -N fzf-ghq
      bindkey '^g' fzf-ghq
      # source <(nerdctl completion zsh)
      . "$HOME/.nix-profile/share/asdf-vm/asdf.sh"

      alias "??"="gh copilot suggest -t shell"
      alias "git?"="gh copilot suggest -t git"
      alias "gh?"="gh copilot suggest -t gh"
      alias "?"="gh copilot explain"
      eval "$(mise activate zsh)"
      eval "$(gh copilot alias zsh)"
    '';
  };
}
