{ config, ... }:

let
  zshConfig = import ../settings/zsh-config.nix;
in

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      c = "code .";
      rel = "source ~/.zshrc";
    };

    initContent = builtins.concatStringsSep "\n" [
      zshConfig.completions
      zshConfig.aliases
      zshConfig.path
      zshConfig.secrets
    ];
  };
}
