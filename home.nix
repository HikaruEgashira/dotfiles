{
  imports = [
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/programs/git.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/zsh.nix
    ./home/programs/mcp-servers.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = "hikae";
    homeDirectory = "/Users/hikae";
    stateVersion = "23.11";
    enableNixpkgsReleaseCheck = false;
  };
}
