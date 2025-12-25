{
  imports = [
    ./modules/home.nix
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/programs/git.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/zsh.nix
    ./modules/programs/mcp-servers.nix
    ./modules/settings/claude.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;
  programs.mcp-servers.enable = false;
}
