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
        editor = "zed --wait";
        hooksPath = hooksDir;
      };

      gpg.format = "ssh";
      signing.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;

      # Xcode's system gitconfig registers osxkeychain as a generic helper that
      # is read first and can return a stale token for the wrong account. The
      # leading "" resets the accumulated helper list per host so only gh
      # (which always serves the active gh account's token) is consulted.
      credential = {
        "https://github.com".helper = [
          ""
          ghCredentialHelper
        ];
        "https://gist.github.com".helper = [
          ""
          ghCredentialHelper
        ];
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
        undo = "reset --soft HEAD~1";
        sync = "!git switch \"$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')\" && git pull";
      };
    };

    ignores = [
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      ".claude/ralph-loop.local.md"
      ".claude/tmp"
      ".claude/worktrees/"
      ".codex/config.toml"
      ".codex/hooks.json"
      ".entire/"
      ".env"
      ".env.keys"
      ".env.local"
      ".idea/tasks.xml"
      ".idea/workspace.xml"
      ".vscode/launch.json"
      ".vscode/settings.json"
      "*.swo"
      "environment.toml"
      "*.zip"
      "*.swp"
      "*~"
      "CLAUDE.local.md"
      "Desktop.ini"
      "PROGRESS.md"
      "TASKS.md"
      "Thumbs.db"
      "ehthumbs.db"
      "memo"
      "memo.md"
      "settings.local.json"
      "todo.md"
    ];
  };

  xdg.configFile."git/hooks/pre-commit".source = preCommit;

  # ~/.gitconfig overrides ~/.config/git/config; legacy keys must be unset
  home.activation = {
    purgeStaleGitUserIdentity = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      gitconfig="$HOME/.gitconfig"
      [ -f "$gitconfig" ] || exit 0
      for key in user.email user.name; do
        if ${pkgs.git}/bin/git config --file "$gitconfig" --get "$key" >/dev/null 2>&1; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --unset "$key" || true
        fi
      done
    '';

    purgeStaleGhCredentialHelper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

    purgeStaleGitExcludesFile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      gitconfig="$HOME/.gitconfig"
      [ -f "$gitconfig" ] || exit 0
      if ${pkgs.git}/bin/git config --file "$gitconfig" --get-all core.excludesfile >/dev/null 2>&1; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --unset-all core.excludesfile || true
      fi
    '';
  };
}
