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
      rel = "source ~/.zshrc";
      ghq = "gh q";
      up = "claude-compose up";
      down = "claude-compose down";
      log = "claude-compose log -f";
    };

    initContent = builtins.concatStringsSep "\n" [
      # 未設定だと複数行貼り付けの `#` 行末コメントが引数として実行される
      "setopt interactive_comments"

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
          "$HOME/.local/share/aquaproj-aqua/bin"
          "$HOME/.local/bin"
          "$HOME/.local/share/npm-global/bin"
          "$HOME/.pdtm/go/bin"
          "$HOME/.spicetify"
          /usr/local/bin
          $path
        )
        export PATH
      ''
    ];
  };
}
