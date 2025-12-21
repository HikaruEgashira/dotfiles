{ config, pkgs, lib, ... }:

{
  options.programs.mcp-servers = {
    enable = lib.mkEnableOption "MCP Servers configuration";
  };

  config = lib.mkIf config.programs.mcp-servers.enable {
    home.packages = with pkgs; [
      dotenvx
      nodejs
    ];

    # Store MCP servers configuration in ~/dotfiles/home/programs/mcp-servers/
    # Encrypted API keys are loaded from ~/.config/secrets/.env via dotenvx
    xdg.configFile."mcp-servers".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/home/programs/mcp-servers";
  };
}
