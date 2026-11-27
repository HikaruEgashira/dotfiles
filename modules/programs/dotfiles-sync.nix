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

    # ~/dotfiles は sandbox から書けるので、checkout の内容・ref・.git/config を一切使わない。
    # origin の main の SHA を取り、その commit を github: で固定して build する
    head_before=$(cat "${metricsDir}/applied" 2>/dev/null || echo "")
    sha=$(git ls-remote https://github.com/HikaruEgashira/dotfiles refs/heads/main | cut -f1)
    case "$sha" in
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
      *) echo "skip: cannot resolve origin main"; outcome="skip-no-origin"; exit 0 ;;
    esac
    head_after="$sha"
    flake="github:HikaruEgashira/dotfiles/$sha"

    # OS 層は root が要るので build して未適用を記録するだけ。ユーザー層は root 不要なのでここで適用する
    case "$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)" in
      Mac-Studio) host=mac-studio; homeHost=hikae@mac-studio ;;
      *) host=hikae; homeHost=hikae ;;
    esac
    built=$(nix build --no-link --print-out-paths "$flake#darwinConfigurations.$host.system")
    current=$(readlink -f /run/current-system 2>/dev/null || echo "")
    if [ "$built" != "$current" ]; then
      pending="yes"
    else
      pending="no"
    fi
    home=$(nix build --no-link --print-out-paths "$flake#homeConfigurations.\"$homeHost\".activationPackage")
    "$home/activate" >/dev/null
    echo "$sha" >"${metricsDir}/applied"
    outcome="applied"

    # 報告のみ: drift があっても同期の成否は変えない (unknown は audit 自体の実行失敗)
    audit_verdict=$(nix run "$flake#xdg-audit" 2>/dev/null | grep -o 'drift=[01]' | cut -d= -f2 | tail -n1 || true)
    if [ "$audit_verdict" = "1" ]; then
      xdg_drift="drift"
    elif [ "$audit_verdict" = "0" ]; then
      xdg_drift="none"
    else
      xdg_drift="unknown"
    fi

    # 宣言外の launchd agent が常駐していれば drift として記録する (runner 登録等の検出)
    if nix run "$flake#launchd-audit" >/dev/null 2>&1; then
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
