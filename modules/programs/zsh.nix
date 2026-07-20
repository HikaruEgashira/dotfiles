_:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    envExtra = ''
      # nix-installer PR#714 gates /etc/zshenv behind SSH_CONNECTION
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

        export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
        mkdir -p "$TF_PLUGIN_CACHE_DIR" 2>/dev/null

        export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
        export PATH=$PATH:$HOME/.spicetify
        export PATH=$PATH:$HOME/.local/bin
        export PATH=$PATH:$HOME/.pdtm/go/bin
        command -v mise &>/dev/null && eval "$(mise activate zsh)" 2>/dev/null || true
      ''

      # child shells inherit; skip the dotenvx round-trip on re-entry
      ''
        if [ -z "''${OPENAI_API_KEY-}" ] && [ -f "$HOME/.config/secrets/.env.keys" ] && command -v dotenvx >/dev/null 2>&1; then
          export DOTENV_PRIVATE_KEY=$(sed -n 's/^DOTENV_PRIVATE_KEY=//p' "$HOME/.config/secrets/.env.keys")
          eval "$(cd "$HOME/.config/secrets" && dotenvx run --quiet -- sh -c '
            for k in OPENAI_API_KEY NPM_TOKEN GH_PKG_TOKEN FLATT_GUARD_TOKEN ZAI_API_KEY; do
              eval "v=\$$k"
              [ -n "$v" ] && printf "export %s=%q\n" "$k" "$v"
            done
          ')"
          [ -n "''${FLATT_GUARD_TOKEN-}" ] && export UV_INDEX_URL="https://token:$FLATT_GUARD_TOKEN@pypi.flatt.tech/simple/"
        fi
      ''

      (builtins.readFile ../settings/send-claude.zsh)
    ];
  };
}
