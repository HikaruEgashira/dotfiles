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
      c = "claude";
      con = "claude -c continue";
      o = "opencode";
      z = "zod .";
      q = "gh q --";
      rel = "source ~/.zshrc";
      ghq = "gh q";
      say = "mise exec github:HikaruEgashira/say -- say";
    };

    initContent = builtins.concatStringsSep "\n" [
      # aliases
      ''
        review() { claude "/review-flow $1"; }
        current() { claude "/current-pr gh pr view | head -n 150 => $(gh pr view | head -n 150), gh pr diff | head -n 50 => $(gh pr diff | head -n 50) $1"; }
      ''

      # rust
      ''
        export CARGO_TARGET_DIR="$HOME/.cargo-target"
        export RUSTC_WRAPPER=sccache
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
