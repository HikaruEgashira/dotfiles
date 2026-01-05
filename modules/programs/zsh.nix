{ config, ... }:

let
  zshConfig = import ../settings/zsh-config.nix;
in

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      c = "code .";
      con = "claude -c continue";
      q = "gh q --";
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
