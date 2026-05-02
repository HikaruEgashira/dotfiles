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

  ghCredentialHelper = "!${pkgs.gh}/bin/gh auth git-credential";
in
{
  programs.git = {
    enable = true;
    signing.format = "ssh";

    settings = {
      user.name = "HikaruEgashira";
      user.email = "39324739+HikaruEgashira@users.noreply.github.com";

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

      credential = {
        "https://github.com".helper = ghCredentialHelper;
        "https://gist.github.com".helper = ghCredentialHelper;
      };

      # SSH transport is banned; all GitHub URLs are rewritten to HTTPS
      url = {
        "https://github.com/".insteadOf = [
          "git@github.com:"
          "ssh://git@github.com/"
        ];
        "https://gist.github.com/".insteadOf = [
          "git@gist.github.com:"
          "ssh://git@gist.github.com/"
        ];
      };

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

  # ~/.gitconfig overrides ~/.config/git/config; legacy keys must be unset
  home.activation.purgeStaleGitUserIdentity = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    gitconfig="$HOME/.gitconfig"
    [ -f "$gitconfig" ] || exit 0
    for key in user.email user.name; do
      if ${pkgs.git}/bin/git config --file "$gitconfig" --get "$key" >/dev/null 2>&1; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --unset "$key" || true
      fi
    done
  '';

  home.activation.purgeStaleGhCredentialHelper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    gitconfig="$HOME/.gitconfig"
    [ -f "$gitconfig" ] || exit 0
    for host in github.com gist.github.com; do
      key="credential.https://$host.helper"
      if ${pkgs.git}/bin/git config --file "$gitconfig" --get-all "$key" >/dev/null 2>&1; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --unset-all "$key" || true
      fi
      if ! ${pkgs.git}/bin/git config --file "$gitconfig" --get-regexp "^credential\\.https://$host\\." >/dev/null 2>&1; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --remove-section "credential.https://$host" 2>/dev/null || true
      fi
    done
  '';
}
