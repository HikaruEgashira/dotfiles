# Load encrypted secrets using dotenvx
# MCP Servers API keys are stored in ~/.config/secrets/.env (encrypted with dotenvx)
if [ -f "$HOME/.config/secrets/.env.keys" ]; then
  export DOTENV_PRIVATE_KEY=$(sed -n 's/^DOTENV_PRIVATE_KEY=//p' "$HOME/.config/secrets/.env.keys")
  eval "$(cd "$HOME/.config/secrets" && dotenvx run --quiet -- sh -c 'echo OPENAI_API_KEY=$OPENAI_API_KEY')"
fi
