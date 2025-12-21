{ config, ... }:

{
  programs.git = {
    enable = true;

    userName = "hikae";
    userEmail = "account@egahika.dev";

    extraConfig = {
      core = {
        whitespace = "trailing-space,space-before-tab";
        editor = "code --wait";
      };
      gpg.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;
      alias = {
        st = "status -sb";
        co = "checkout";
        br = "branch";
        ci = "commit";
      };
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".envrc"
      ".direnv"
    ];
  };
}
