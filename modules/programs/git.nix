{ config, ... }:

{
  programs.git = {
    enable = true;

    settings.user.name = "hikae";
    settings.user.email = "account@egahika.dev";

    settings.core = {
      whitespace = "trailing-space,space-before-tab";
      editor = "code --wait";
    };

    settings.gpg.format = "ssh";
    settings.init.defaultBranch = "main";
    settings.pull.rebase = true;
    settings.fetch.prune = true;

    settings.alias = {
      st = "status -sb";
      co = "checkout";
      br = "branch";
      ci = "commit";
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".envrc"
      ".direnv"
    ];
  };
}
