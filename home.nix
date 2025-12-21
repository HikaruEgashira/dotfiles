{
  imports = [
    # Core Home Manager settings
    ./modules/home.nix

    # Package management
    ./modules/packages.nix

    # Font configuration
    ./modules/fonts.nix

    # Program configurations
    ./modules/programs/git.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/zsh.nix
    ./modules/programs/mcp-servers.nix

    # User settings and customizations
    ./modules/settings/claude.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;
  programs.mcp-servers.enable = false;
}
