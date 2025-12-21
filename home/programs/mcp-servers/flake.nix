{
  description = "Claude Code MCP servers configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      mcp-servers-nix,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ mcp-servers-nix.flakeModule ];

      systems = [ "aarch64-darwin" "x86_64-darwin" ];

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        {
          # Configure MCP servers
          # API keys are loaded from ~/.config/secrets/.env via envFile
          mcp-servers = {
            programs = {
              tavily = {
                enable = true;
                envFile = "${builtins.getEnv "HOME"}/.config/secrets/.env";
              };
              context7 = {
                enable = true;
                envFile = "${builtins.getEnv "HOME"}/.config/secrets/.env";
              };
              memory = {
                enable = true;
                envFile = "${builtins.getEnv "HOME"}/.config/secrets/.env";
                env.CLIENT_NAME = "kiro";
              };
            };

            # Custom servers not available as modules
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

            # Generate Claude Code configuration
            flavors.claude-code.enable = true;
          };

          # Use the generated devShell
          devShells.default = config.mcp-servers.devShell;
        };
    };
}
