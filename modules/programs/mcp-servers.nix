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

    xdg.configFile."mcp-servers".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/modules/settings/mcp-servers";

    home.file.".mcp.json".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/modules/settings/mcp-servers/.mcp.json";
  };
}
