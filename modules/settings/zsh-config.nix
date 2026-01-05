{
  completions = ''
  '';

  aliases = ''
    alias c="code ."
    alias rel="source ~/.zshrc"

    watch() { claude "/watch-pr $1"; }
    review() { claude "/review-pr $1"; }
    current() { claude "/current-pr gh pr view | head -n 150 => $(gh pr view | head -n 150), gh pr diff | head -n 50 => $(gh pr diff | head -n 50) $1"; }
  '';

  path = ''
    export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
    export PATH=$PATH:$HOME/.spicetify
    export PATH=$PATH:$HOME/.local/bin
    export PATH=$PATH:$HOME/.pdtm/go/bin
    export PATH=$HOME/.opencode/bin:$PATH

    command -v mise &>/dev/null && eval "$(mise activate zsh)" 2>/dev/null || true
  '';

  secrets = ''
    if [ -f "$HOME/.config/secrets/.env.keys" ]; then
      export DOTENV_PRIVATE_KEY=$(sed -n 's/^DOTENV_PRIVATE_KEY=//p' "$HOME/.config/secrets/.env.keys")
      eval "$(cd "$HOME/.config/secrets" && dotenvx run --quiet -- sh -c 'echo OPENAI_API_KEY=$OPENAI_API_KEY')"
    fi
  '';
}
