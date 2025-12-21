# PATH configuration
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
export PATH=$PATH:$HOME/.spicetify
export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:$HOME/.pdtm/go/bin

# Tool initialization
command -v mise &>/dev/null && eval "$(mise activate zsh)" 2>/dev/null || true
