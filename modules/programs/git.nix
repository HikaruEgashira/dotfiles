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

      # gh CLI credential helper を nix-store path で固定。
      # 旧 ~/.gitconfig には /opt/homebrew/bin/gh が hardcode されており
      # gh が nix-profile に移った時点で push が device-not-configured で fail していた。
      # 旧設定は home.activation.purgeStaleGhCredentialHelper で unset する。
      credential = {
        "https://github.com".helper = ghCredentialHelper;
        "https://gist.github.com".helper = ghCredentialHelper;
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

  # gh auth setup-git が ~/.gitconfig に書いた絶対パス helper を撤去。
  # ~/.gitconfig の設定は ~/.config/git/config を上書きするため、
  # この unset を行わないと HM 管理側の credential helper は効かない。
  # 冪等: 対象キーが無ければ no-op で抜ける。
  home.activation.purgeStaleGhCredentialHelper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    gitconfig="$HOME/.gitconfig"
    [ -f "$gitconfig" ] || exit 0
    for host in github.com gist.github.com; do
      key="credential.https://$host.helper"
      if ${pkgs.git}/bin/git config --file "$gitconfig" --get-all "$key" >/dev/null 2>&1; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --unset-all "$key" || true
      fi
      # 残った空の [credential "https://..."] section を削除
      if ${pkgs.git}/bin/git config --file "$gitconfig" --get-regexp "^credential\\.https://$host\\." >/dev/null 2>&1; then
        : # まだ他 key が残っているならセクションは残す
      else
        $DRY_RUN_CMD ${pkgs.git}/bin/git config --file "$gitconfig" --remove-section "credential.https://$host" 2>/dev/null || true
      fi
    done
  '';
}
