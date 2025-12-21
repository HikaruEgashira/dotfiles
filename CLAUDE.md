# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal dotfiles repository managed using Nix and Home Manager for declarative macOS configuration. The repository defines a reproducible development environment including shell configuration, CLI tools, and development utilities.

## Architecture

### Directory Structure

- `home.nix`: Root configuration file that imports all modules
- `modules/`: Core Home Manager modules
  - `home.nix`: User home directory configuration
  - `packages.nix`: System packages
  - `fonts.nix`: Font configuration
  - `programs/`: Individual program configurations (git, zsh, cli-tools)
- `home/`: User-specific files and programs
  - `files.nix`: Home files managed by Home Manager (including Claude Code settings)
  - `programs/`: Additional programs (MCP servers integration)
- `configs/`: Shell configuration scripts loaded by zsh
- `scanner/`: Separate project directory (scanner application)

### Configuration Flow

1. `home.nix` imports all modules from `modules/` and `home/`
2. Each module is responsible for one aspect of the environment
3. `home/files.nix` manages dotfiles including `.claude/CLAUDE.md` (this file is managed via Home Manager)
4. Shell configurations are loaded from `configs/zsh/` by `modules/programs/zsh.nix`
5. MCP servers configuration is symlinked to `~/.config/mcp-servers`

## Common Commands

### Home Manager

```bash
# Apply changes from this configuration
nix run home-manager -- -f ~/dotfiles/home.nix switch

# Back up previous generation before switching
nix run home-manager -- -f ~/dotfiles/home.nix switch -b backup

# Show what would change (dry run)
nix run home-manager -- -f ~/dotfiles/home.nix switch --dry-run
```

### Development

```bash
# Reload zsh configuration
rel

# Open current directory in code
c

# Use mise for version management
mise ls          # List installed tools
mise use <tool>  # Set tool version
```

### Testing Changes

Before committing:

1. Apply Home Manager changes: `nix run home-manager -- -f ~/dotfiles/home.nix switch`
2. Test shell: `zsh` or `rel` to reload
3. Verify tools work: `mise ls`, `fd`, `rg`, `git status`
4. Check if files were created/modified as expected in home directory

## Key Configuration Details

### Module Responsibilities

- `modules/programs/git.nix`: Git configuration with SSH GPG signing
- `modules/programs/zsh.nix`: Zsh setup with completions and syntax highlighting; loads scripts from `configs/zsh/`
- `modules/programs/cli-tools.nix`: direnv, fzf, bat, lsd, aria2, starship
- `home/files.nix`: Manages Claude Code settings (model, CLAUDE.md instructions)
- `home/programs/mcp-servers.nix`: MCP servers integration with dotenvx for secrets

### MCP Servers Integration

The repository integrates MCP (Model Context Protocol) servers for Claude tools:

- Configuration stored in `home/programs/mcp-servers/`
- API keys encrypted using dotenvx at `~/.config/secrets/.env`
- Symlinked to `~/.config/mcp-servers` for use by Claude applications
- See `home/programs/mcp-servers/README.md` for setup details

### Shell Configuration

Shell initialization files in `configs/zsh/` are loaded in order:
1. `completions.zsh` - Custom completions
2. `aliases.zsh` - Shell aliases
3. `path.zsh` - PATH and tool initialization (mise)
4. `secrets.zsh` - Local secrets (git-ignored)

## Important Notes

- This configuration is declarative - changes should be made in `.nix` files, not directly in home directory
- `modules/programs/zsh.nix` reads files from `configs/zsh/` - changes there require a Home Manager switch to apply
- Claude Code settings are managed via `home/files.nix` - the CLAUDE.md file is maintained through Home Manager
- The `.env.keys` file for MCP secrets is git-ignored
- Changes to this repository should follow conventional commits
