{
  config,
  pkgs,
  lib,
  ...
}:

let
  hooksDir = "${config.xdg.configHome}/git/hooks";
  userEmail = "39324739+HikaruEgashira@users.noreply.github.com";
  signingPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWXJjbIw2llLUJvEIJtklUkgdJAAfso2Jgoi+OaH0v9";

  preCommit = pkgs.writeShellScript "global-pre-commit" (builtins.readFile ./git/pre-commit.sh);

  # ghtkn (modules/programs/ghtkn.nix) が keychain に持つ 8h の user access token を返す
  ghCredentialHelper = "!${pkgs.ghtkn}/bin/ghtkn git-credential";

  # git-lfs invoked by absolute store path: hooks must survive PATH-sanitized
  # environments (e.g. Homebrew's superenv during `brew tap`)
  lfsHook =
    name:
    pkgs.writeShellScript "git-lfs-${name}" ''
      exec ${pkgs.git-lfs}/bin/git-lfs ${name} "$@"
    '';
  lfsHookNames = [
    "post-checkout"
    "post-commit"
    "post-merge"
    "pre-push"
  ];
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    signing = {
      format = "ssh";
      # key:: 形式で agent に委譲する (秘密鍵ファイルは読まない)
      key = "key::${signingPubKey}";
      signByDefault = true;
      # 検証データは公開情報なので repo 所有。principal は commit email に揃え、鍵を替えたらここも更新する
      allowedSigners = "${userEmail} ${signingPubKey}\n";
    };

    settings = {
      user.name = "HikaruEgashira";
      user.email = userEmail;

      core = {
        whitespace = "trailing-space,space-before-tab";
        editor = "nvim";
        hooksPath = hooksDir;
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;

      # Xcode's system gitconfig registers osxkeychain as a generic helper that
      # is read first and can return a stale token for the wrong account. The
      # leading "" resets the accumulated helper list per host so only ghtkn
      # is consulted.
      credential = {
        # ghtkn git-credential はリポジトリ owner で app を選ぶため path を渡す (無いと毎回 WRN が出る)
        useHttpPath = true;
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
        undo = "!f() { test -z \"$(git status --porcelain --untracked-files=no)\" || { echo 'git undo: commit or stash local changes first' >&2; exit 1; }; subject=$(git log -1 --format=%s) && git reset --soft HEAD~1 && git stash push --staged -m \"undo: $subject\"; }; f";
        redo = ''!f() { s=$(git stash list -1 --format=%gs) && case "$s" in *undo:*) git stash pop --index && git commit -m "''${s#*undo: }";; *) echo 'git redo: top stash was not created by git undo' >&2; exit 1;; esac; }; f'';
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

  xdg.configFile = {
    "git/hooks/pre-commit".source = preCommit;
  }
  // lib.listToAttrs (
    map (name: {
      name = "git/hooks/${name}";
      value = {
        source = lfsHook name;
        # `git lfs install` previously wrote unmanaged hooks here; clobber them
        force = true;
      };
    }) lfsHookNames
  );

  # ~/.gitconfig overrides ~/.config/git/config; legacy keys must be unset
  home.activation.purgeStaleGitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    gitconfig="$HOME/.gitconfig"
    for key in \
      user.email user.name core.excludesfile core.editor \
      user.signingkey commit.gpgsign gpg.format gpg.ssh.allowedSignersFile \
      coderabbit.machineId; do
      if ${pkgs.git}/bin/git config --file "$gitconfig" --get-all "$key" >/dev/null 2>&1; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --unset-all "$key" || true
      fi
    done
    # `git lfs install` writes a PATH-dependent filter.lfs here; HM owns an absolute-path copy
    if ${pkgs.git}/bin/git config --file "$gitconfig" --get-regexp '^filter\.lfs\.' >/dev/null 2>&1; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --remove-section filter.lfs || true
    fi
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
