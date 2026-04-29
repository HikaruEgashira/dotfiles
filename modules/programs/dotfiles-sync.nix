{
  config,
  pkgs,
  lib,
  ...
}:

let
  syncScript = pkgs.writeShellScript "dotfiles-sync" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.git
        pkgs.nix
        pkgs.coreutils
      ]
    }:$PATH

    cd "$HOME/dotfiles"

    # main 以外で動いている時はスキップ (作業中ブランチを壊さない)
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$branch" != "main" ]; then
      echo "skip: not on main (current=$branch)"
      exit 0
    fi

    # dirty なら作業中なのでスキップ
    if ! git diff --quiet HEAD --; then
      echo "skip: dirty working tree"
      exit 0
    fi

    git fetch --quiet origin main
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
      echo "skip: already up to date"
      exit 0
    fi

    git pull --ff-only --quiet origin main
    nix run ".#homeConfigurations.hikae.activationPackage" --no-warn-dirty
  '';
in
{
  launchd.agents.dotfiles-sync = {
    enable = true;
    config = {
      Label = "dev.egahika.dotfiles-sync";
      ProgramArguments = [ "${syncScript}" ];
      StartCalendarInterval = [
        {
          Hour = 9;
          Minute = 0;
        }
      ];
      RunAtLoad = false;
      StandardOutPath = "${config.home.homeDirectory}/.cache/dotfiles-sync.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/dotfiles-sync.err";
    };
  };
}
