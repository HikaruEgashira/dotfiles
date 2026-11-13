# Windows 側で Mac の英数/かな相当 (左 Win(Mac 配列の Cmd) 単押しで IME OFF、右 Win(Cmd) 単押しで IME ON) を有効にする。OS 標準に単押し hotkey が無いため AutoHotkey v2 で実現する。
# スクリプトは Startup フォルダへ実ファイルとして複製し、ログオン時に自動起動させる。
{
  lib,
  pkgs,
  ...
}:

let
  script = ./cmd-tap-ime.ahk;
in
{
  home.activation.windowsCmdTapIme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    cmd=/mnt/c/Windows/System32/cmd.exe
    appData=$($cmd /d /c 'echo %APPDATA%' 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '\r' || true)
    if [ -n "''${WSL_DISTRO_NAME:-}" ] && [ -n "$appData" ]; then
      startup="$(/bin/wslpath -u "$appData")/Microsoft/Windows/Start Menu/Programs/Startup"
      # 旧版の Alt 単押し版が残ると二重に hook するため消す
      $DRY_RUN_CMD rm -f "$startup/alt-tap-ime.ahk"
      dst="$startup/cmd-tap-ime.ahk"
      $DRY_RUN_CMD mkdir -p "$startup"
      $DRY_RUN_CMD cp --no-preserve=mode ${script} "$dst"
      # .ahk の関連付けが無ければ AutoHotkey v2 を user scope で導入する
      if ! $cmd /d /c 'assoc .ahk' >/dev/null 2>&1; then
        $DRY_RUN_CMD /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command \
          'winget install --id AutoHotkey.AutoHotkey -e --scope user --silent --accept-package-agreements --accept-source-agreements' \
          || echo "windowsCmdTapIme: AutoHotkey install failed; install AutoHotkey v2 manually" >&2
      fi
      # #SingleInstance Force により既存プロセスは置き換わる
      $DRY_RUN_CMD $cmd /d /c start "" "$(/bin/wslpath -w "$dst")" >/dev/null 2>&1 || true
    else
      echo "windowsCmdTapIme: Windows interop unavailable; skipping" >&2
    fi
  '';
}
