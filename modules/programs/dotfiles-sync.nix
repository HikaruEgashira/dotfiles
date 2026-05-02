{
  config,
  pkgs,
  lib,
  ...
}:

let
  metricsDir = "${config.home.homeDirectory}/.cache/dotfiles-sync";
  metricsFile = "${metricsDir}/metrics.jsonl";

  syncScript = pkgs.writeShellScript "dotfiles-sync" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.git
        pkgs.nix
        pkgs.coreutils
      ]
    }:$PATH

    mkdir -p "${metricsDir}"

    started_at=$(date -u +%s)
    head_before=""
    head_after=""
    outcome="error"

    write_metric() {
      ended_at=$(date -u +%s)
      wall_s=$(( ended_at - started_at ))
      ts=$(date -u +%FT%TZ)
      printf '{"ts":"%s","outcome":"%s","wall_s":%d,"head_before":"%s","head_after":"%s"}\n' \
        "$ts" "$outcome" "$wall_s" "$head_before" "$head_after" \
        >>"${metricsFile}"
    }
    trap write_metric EXIT

    cd "$HOME/dotfiles"
    head_before=$(git rev-parse HEAD 2>/dev/null || echo "")
    head_after="$head_before"

    # main 以外で動いている時はスキップ (作業中ブランチを壊さない)
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$branch" != "main" ]; then
      echo "skip: not on main (current=$branch)"
      outcome="skip-not-main"
      exit 0
    fi

    # dirty なら作業中なのでスキップ
    if ! git diff --quiet HEAD --; then
      echo "skip: dirty working tree"
      outcome="skip-dirty"
      exit 0
    fi

    git fetch --quiet origin main
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
      echo "skip: already up to date"
      outcome="skip-up-to-date"
      exit 0
    fi

    git pull --ff-only --quiet origin main
    head_after=$(git rev-parse HEAD)
    nix run ".#homeConfigurations.hikae.activationPackage" --no-warn-dirty
    outcome="activated"
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
