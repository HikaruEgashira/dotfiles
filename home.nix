{
  imports = [
    ./modules/home.nix
    ./modules/programs/xdg.nix
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/programs/git.nix
    ./modules/programs/ghtkn.nix
    ./modules/programs/ssh.nix
    ./modules/programs/aws.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/aqua.nix
    ./modules/programs/nvim/default.nix
    ./modules/programs/zsh.nix
    ./modules/programs/direnv.nix
    ./modules/programs/tmux.nix
    ./modules/programs/ghostty.nix
    ./modules/programs/t3code
    ./modules/programs/harness/ai-sandbox.nix
    ./modules/programs/harness/ai-cli.nix
    ./modules/programs/harness/claude.nix
    ./modules/programs/harness/codex.nix
    ./modules/programs/harness/opencode.nix
    ./modules/programs/harness/pi.nix
    ./modules/programs/cmux.nix
    ./modules/programs/herdr.nix
    ./modules/programs/harness/hermes.nix

    ./modules/programs/dotfiles-sync.nix
    ./modules/programs/artex.nix
    ./modules/programs/clean-worktree.nix
    ./modules/programs/disk-maintenance.nix
  ];

  programs.home-manager.enable = true;
}
