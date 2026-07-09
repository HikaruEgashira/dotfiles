{ config, ... }:
{
  # LazyVim owns ~/.config/nvim and writes lazy-lock.json at runtime, so an
  # out-of-store symlink to the repo keeps the config live-editable and tracked
  # instead of the read-only store copy home.file.source would produce.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/programs/nvim/config";
}
