{ config, ... }:

{
  programs.git = {
    enable = true;
    userName = "hikae";
    userEmail = "account@egahika.dev";

    signing = {
      key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      signByDefault = true;
      gpgPath = "ssh";
    };

    extraConfig = {
      core = {
        whitespace = "trailing-space,space-before-tab";
        editor = "code --wait";
      };
      gpg.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".envrc"
      ".direnv"
    ];

    aliases = {
      st = "status -sb";
      co = "checkout";
      br = "branch";
      ci = "commit";
    };
  };
}
