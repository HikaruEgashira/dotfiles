{ config, ... }:

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

    initExtra = builtins.concatStringsSep "\n" [
      (builtins.readFile ../../configs/zsh/completions.zsh)
      (builtins.readFile ../../configs/zsh/aliases.zsh)
      (builtins.readFile ../../configs/zsh/path.zsh)
      (builtins.readFile ../../configs/zsh/secrets.zsh)
    ];
  };
}
