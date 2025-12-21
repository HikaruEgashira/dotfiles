{ config, ... }:

{
  programs.git = {
    enable = true;

    signing = {
      key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      signByDefault = true;
      signer = "ssh";
    };

    settings = {
      user = {
        name = "hikae";
        email = "account@egahika.dev";
      };
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
