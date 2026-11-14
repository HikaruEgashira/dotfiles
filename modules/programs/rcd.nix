{ lib, pkgs, ... }:

# rcd は再生キーや Bluetooth ヘッドホン接続を拾うと再生中アプリが無いとき Music.app を起動するため止める
lib.mkIf pkgs.stdenv.isDarwin {
  home.activation.disableRcd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    uid=$(/usr/bin/id -u)
    run /bin/launchctl disable "gui/$uid/com.apple.rcd"
    run /bin/launchctl bootout "gui/$uid/com.apple.rcd" 2>/dev/null || true
  '';
}
