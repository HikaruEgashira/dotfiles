# Claude Code MCP Servers Configuration
# This file loads encrypted API keys from ~/.config/secrets/.env via dotenvx
#
# Setup:
# 1. Create ~/.config/secrets/.env with your API keys
# 2. Encrypt it: dotenvx encrypt ~/.config/secrets/.env
# 3. chmod 600 ~/.config/secrets/.env.keys

let
  pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/heads/nixos-unstable.tar.gz") { };
  mcp-servers = import (builtins.fetchGit "https://github.com/natsukium/mcp-servers-nix") { inherit pkgs; };
in
mcp-servers.lib.mkConfig pkgs {
  # Load API keys from encrypted .env file
  envFile = "${builtins.getEnv "HOME"}/.config/secrets/.env";

  programs = {
    tavily.enable = true;
    context7.enable = true;
    memory = {
      enable = true;
      env.CLIENT_NAME = "kiro";
    };
  };

  settings.servers = {
    deepwiki = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [
        "-y"
        "mcp-remote"
        "https://mcp.deepwiki.com/sse"
      ];
    };
    cerebras-mcp = {
      command = "${pkgs.nodejs}/bin/node";
      args = [];
      env.CEREBRAS_MCP_IDE = "kiro";
    };
  };
}
