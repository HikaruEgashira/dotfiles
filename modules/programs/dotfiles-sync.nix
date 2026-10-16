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
        pkgs.gnugrep
      ]
    }:$PATH

    mkdir -p "${metricsDir}"

    started_at=$(date -u +%s)
    head_before=""
    head_after=""
    outcome="error"
    xdg_drift="not-run"

    write_metric() {
      ended_at=$(date -u +%s)
      wall_s=$(( ended_at - started_at ))
      ts=$(date -u +%FT%TZ)
      printf '{"ts":"%s","outcome":"%s","wall_s":%d,"head_before":"%s","head_after":"%s","xdg_drift":"%s"}\n' \
        "$ts" "$outcome" "$wall_s" "$head_before" "$head_after" "$xdg_drift" \
        >>"${metricsFile}"
    }
    trap write_metric EXIT

    cd "$HOME/dotfiles"
    head_before=$(git rev-parse HEAD 2>/dev/null || echo "")
    head_after="$head_before"

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$branch" != "main" ]; then
      echo "skip: not on main (current=$branch)"
      outcome="skip-not-main"
      exit 0
    fi

    if ! git diff --quiet HEAD --; then
      echo "skip: dirty working tree"
      outcome="skip-dirty"
      exit 0
    fi

    git fetch --quiet origin main
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
      git pull --ff-only --quiet origin main
      head_after=$(git rev-parse HEAD)
    fi

    nix run ".#homeConfigurations.hikae.activationPackage" --no-warn-dirty
    outcome="activated"

    # 報告のみ: drift があっても同期の成否は変えない (unknown は audit 自体の実行失敗)
    audit_verdict=$(nix run ".#xdg-audit" 2>/dev/null | grep -o 'drift=[01]' | cut -d= -f2 | tail -n1 || true)
    if [ "$audit_verdict" = "1" ]; then
      xdg_drift="drift"
    elif [ "$audit_verdict" = "0" ]; then
      xdg_drift="none"
    else
      xdg_drift="unknown"
    fi
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
