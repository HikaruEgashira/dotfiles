# Zsh shell configuration consolidation
# Replaces configs/zsh/ scripts with Nix configuration
{
  # Completions: Nix and tool completions
  # (nerdctl completion skipped due to lima dependency)
  completions = ''
    # Nix and tool completions
    # nerdctl completion は lima に依存するためスキップ
  '';

  # Aliases: Shell shortcuts
  aliases = ''
    # Custom aliases
    alias c="code ."
    alias rel="source ~/.zshrc"
  '';

  # PATH configuration: Tool path setup and initialization
  path = ''
    # PATH configuration
    export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
    export PATH=$PATH:$HOME/.spicetify
    export PATH=$PATH:$HOME/.local/bin
    export PATH=$PATH:$HOME/.pdtm/go/bin

    # Tool initialization
    command -v mise &>/dev/null && eval "$(mise activate zsh)" 2>/dev/null || true
  '';

  # Secrets: Load encrypted credentials
  secrets = ''
    # Load encrypted secrets using dotenvx
    # MCP Servers API keys are stored in ~/.config/secrets/.env (encrypted with dotenvx)
    if [ -f "$HOME/.config/secrets/.env.keys" ]; then
      export DOTENV_PRIVATE_KEY=$(sed -n 's/^DOTENV_PRIVATE_KEY=//p' "$HOME/.config/secrets/.env.keys")
      eval "$(cd "$HOME/.config/secrets" && dotenvx run --quiet -- sh -c 'echo OPENAI_API_KEY=$OPENAI_API_KEY')"
    fi
  '';
}
