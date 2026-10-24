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
    launchd_drift="not-run"
    pending="unknown"

    write_metric() {
      ended_at=$(date -u +%s)
      wall_s=$(( ended_at - started_at ))
      ts=$(date -u +%FT%TZ)
      printf '{"ts":"%s","outcome":"%s","wall_s":%d,"head_before":"%s","head_after":"%s","xdg_drift":"%s","launchd_drift":"%s","pending":"%s"}\n' \
        "$ts" "$outcome" "$wall_s" "$head_before" "$head_after" "$xdg_drift" "$launchd_drift" "$pending" \
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

    # 適用は root (darwin-rebuild) なので、ここでは build まで通して未適用を記録するだけに留める
    built=$(nix build --no-link --print-out-paths ".#darwinConfigurations.hikae.system")
    outcome="built"
    current=$(readlink -f /run/current-system 2>/dev/null || echo "")
    if [ "$built" != "$current" ]; then
      pending="yes"
    else
      pending="no"
    fi

    # 報告のみ: drift があっても同期の成否は変えない (unknown は audit 自体の実行失敗)
    audit_verdict=$(nix run ".#xdg-audit" 2>/dev/null | grep -o 'drift=[01]' | cut -d= -f2 | tail -n1 || true)
    if [ "$audit_verdict" = "1" ]; then
      xdg_drift="drift"
    elif [ "$audit_verdict" = "0" ]; then
      xdg_drift="none"
    else
      xdg_drift="unknown"
    fi

    # 宣言外の launchd agent が常駐していれば drift として記録する (runner 登録等の検出)
    if nix run ".#launchd-audit" >/dev/null 2>&1; then
      launchd_drift="none"
    else
      launchd_drift="drift"
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
