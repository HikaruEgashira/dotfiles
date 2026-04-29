{ config, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    envExtra = ''
      # Nix daemon (nix-installer PR#714 gates /etc/zshenv behind SSH_CONNECTION)
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';

    profileExtra = ''
      export PATH="$HOME/.local/share/mise/shims:$PATH"
    '';

    shellAliases = {
      claude = "claudex";
      c = "claudex";
      con = "claudex -c continue";
      z = "zod .";
      q = "gh q --";
      rel = "source ~/.zshrc";
      ghq = "gh q";
      say = "mise exec github:HikaruEgashira/say -- say";
      tdev = "bash ~/dotfiles/modules/settings/tmux-dev.sh";
      up = "claude-compose up";
      down = "claude-compose down";
      log = "claude-compose log -f";
    };

    initContent = builtins.concatStringsSep "\n" [
      # gh q fzf → cd (ctrl+g, overrides default send-break)
      ''
        ghq-fzf-cd-widget() {
          local dir
          dir=$(gh q -- pwd) || { zle reset-prompt; return; }
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

      # aliases
      ''
        review() { claude "/review-flow $1"; }
        current() { claude "/current-pr gh pr view | head -n 150 => $(gh pr view | head -n 150), gh pr diff | head -n 50 => $(gh pr diff | head -n 50) $1"; }

        git() {
          local subcmd="" skip_next=0 arg
          for arg in "$@"; do
            if [ $skip_next -eq 1 ]; then skip_next=0; continue; fi
            case "$arg" in
              -c|-C|--git-dir|--work-tree|--namespace|--super-prefix) skip_next=1 ;;
              -*) ;;
              *) subcmd="$arg"; break ;;
            esac
          done
          if [ "$subcmd" = "commit" ] && command -v gitleaks >/dev/null 2>&1; then
            local global_hooks="$HOME/.config/git/hooks"
            local repo_hooks
            repo_hooks=$(command git config --local --get core.hooksPath 2>/dev/null || true)
            if [ -n "$repo_hooks" ] && [ "$repo_hooks" != "$global_hooks" ]; then
              print -u2 "⚠ repo overrides core.hooksPath=$repo_hooks — running gitleaks inline"
              command gitleaks git --staged --redact --no-banner || return $?
            fi
          fi
          command git "$@"
        }
      ''

      # rust
      ''
        export CARGO_TARGET_DIR="$HOME/.cargo-target"
        export RUSTC_WRAPPER=sccache
      ''

      # terraform
      ''
        export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
        mkdir -p "$TF_PLUGIN_CACHE_DIR" 2>/dev/null
      ''

      # path
      ''
        export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
        export PATH=$PATH:$HOME/.spicetify
        export PATH=$PATH:$HOME/.local/bin
        export PATH=$PATH:$HOME/.pdtm/go/bin
        command -v mise &>/dev/null && eval "$(mise activate zsh)" 2>/dev/null || true
      ''

      # secrets
      ''
        if [ -f "$HOME/.config/secrets/.env.keys" ]; then
          export DOTENV_PRIVATE_KEY=$(sed -n 's/^DOTENV_PRIVATE_KEY=//p' "$HOME/.config/secrets/.env.keys")
          eval "$(cd "$HOME/.config/secrets" && dotenvx run --quiet -- sh -c 'echo export OPENAI_API_KEY=$OPENAI_API_KEY; echo export NPM_TOKEN=$NPM_TOKEN; echo export GH_PKG_TOKEN=$GH_PKG_TOKEN; echo export FLATT_GUARD_TOKEN=$FLATT_GUARD_TOKEN; echo export ZAI_API_KEY=$ZAI_API_KEY')"
          export UV_INDEX_URL="https://token:$FLATT_GUARD_TOKEN@pypi.flatt.tech/simple/"
        fi
      ''

      # send-claude
      (builtins.readFile ../settings/send-claude.zsh)
    ];
  };
}
