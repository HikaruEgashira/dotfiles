{ config, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user.name = "hikae";
      user.email = "account@egahika.dev";

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
      "environment.toml"
      "*.swp"
    ];
  };
}
