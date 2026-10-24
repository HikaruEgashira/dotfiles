{ config, ... }:

{
  programs.zsh = {
    enable = true;
    # ZDOTDIR 経由にすると ghostty の shell-integration が .zshrc を握って壊れるため従来配置に固定する
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      z = "zod .";
      q = "gh q bash ~/dotfiles/modules/settings/tmux-dev.sh";
      rel = "source ~/.zshrc";
      ghq = "gh q";
      tdev = "bash ~/dotfiles/modules/settings/tmux-dev.sh";
      up = "claude-compose up";
      down = "claude-compose down";
      log = "claude-compose log -f";
    };

    initContent = builtins.concatStringsSep "\n" [
      ''
        ghq-fzf-cd-widget() {
          local dir
          dir=$(gh q list | fzf --height=40% --reverse) || { zle reset-prompt; return; }
          if [[ -n "$dir" ]]; then
            BUFFER="cd ''${(q)dir}"
            zle accept-line
          else
            zle reset-prompt
          fi
        }
        zle -N ghq-fzf-cd-widget
        bindkey '^G' ghq-fzf-cd-widget
      ''

      ''
        review() { claude "/review-flow $1"; }
        current() { claude "/current-pr gh pr view | head -n 150 => $(gh pr view | head -n 150), gh pr diff | head -n 50 => $(gh pr diff | head -n 50) $1"; }
      ''

      ''
        export CARGO_TARGET_DIR="$HOME/.cargo-target"
        export RUSTC_WRAPPER=sccache

        typeset -U path PATH
        path=(
          "$HOME/.nix-profile/bin"
          "$HOME/.local/bin"
          "$HOME/.local/share/npm-global/bin"
          "$HOME/.opencode/bin"
          "$HOME/.pdtm/go/bin"
          "$HOME/.spicetify"
          /opt/homebrew/bin
          /usr/local/bin
          $path
        )
        export PATH
      ''

      # child shells inherit; skip the decrypt on re-entry
      ''
        # _SECRETS_GEN は「どの世代のキー一覧を読み込み済みか」を表す番号。
        # 下の while が読むキー一覧を変えたら、この番号も上げること。上げ忘れると、古い番号を
        # 持った親プロセス (herdr / tmux 等) 配下のシェルが古い環境を永久に引き継ぎ、
        # 新しいキーが永遠に生えてこない。
        if [ "''${_SECRETS_GEN-}" != "1" ] && [ -r "$HOME/.config/secrets/env.age" ] && command -v age >/dev/null 2>&1; then
          while IFS='=' read -r key value; do
            [ -n "$key" ] && export "$key=$value"
          done < <(age -d -i "$HOME/.config/secrets/age-key.txt" "$HOME/.config/secrets/env.age")
          [ -n "''${FLATT_GUARD_TOKEN-}" ] && export UV_INDEX_URL="https://token:$FLATT_GUARD_TOKEN@pypi.flatt.tech/simple/"
          export _SECRETS_GEN=1
        fi
      ''

      (builtins.readFile ../settings/send-claude.zsh)
    ];
  };
}
