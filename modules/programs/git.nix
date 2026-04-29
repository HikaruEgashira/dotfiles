{
  config,
  pkgs,
  lib,
  ...
}:

let
  hooksDir = "${config.xdg.configHome}/git/hooks";

  preCommit = pkgs.writeShellScript "global-pre-commit" ''
    set -eu

    if command -v gitleaks >/dev/null 2>&1; then
      gitleaks git --staged --redact --verbose --no-banner
    fi

    local_hook="$(git rev-parse --git-dir)/hooks/pre-commit"
    if [ -x "$local_hook" ]; then
      exec "$local_hook" "$@"
    fi
  '';
in
{
  programs.git = {
    enable = true;
    signing.format = "ssh";

    settings = {
      user.name = "hikae";
      user.email = "account@egahika.dev";

      core = {
        whitespace = "trailing-space,space-before-tab";
        editor = "code --wait";
        hooksPath = hooksDir;
      };

      gpg.format = "ssh";
      signing.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;

      alias = {
        st = "status -sb";
        co = "checkout";
        br = "branch";
        ci = "commit";
        sync = "!git switch \"$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')\" && git pull";
      };
    };

    ignores = [
      ".DS_Store"
      "environment.toml"
      "*.swp"
    ];
  };

  xdg.configFile."git/hooks/pre-commit".source = preCommit;
}
