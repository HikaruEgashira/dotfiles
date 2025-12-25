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
          mcp-servers = {
            settings.servers = {
              deepwiki = {
                command = "${pkgs.nodejs}/bin/npx";
                args = [
                  "-y"
                  "mcp-remote"
                  "https://mcp.deepwiki.com/sse"
                ];
              };
            };

            flavors.claude-code.enable = true;
          };

          devShells.default = config.mcp-servers.devShell;
        };
    };
}
