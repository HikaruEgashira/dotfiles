{
  imports = [
    ./modules/home.nix
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/programs/git.nix
    ./modules/programs/aws.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/zsh.nix
    ./modules/programs/tmux.nix
    ./modules/programs/ghostty.nix
    ./modules/programs/claude.nix
    ./modules/programs/cmux.nix
    ./modules/programs/vscode.nix
    ./modules/programs/dotfiles-sync.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;
}
