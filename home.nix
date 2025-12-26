{
  imports = [
    ./modules/home.nix
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/programs/git.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/zsh.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;
}
