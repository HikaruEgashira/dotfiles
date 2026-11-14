{ lib, pkgs, ... }:

let
  # 対応する機能・アプリを使っていないことを確認できたものだけを並べる。共有基盤 (photolibraryd, parsecd, siriactionsd 等) は picker / Spotlight / Shortcuts を壊すので含めない
  disabled = [
    "com.apple.rcd" # 再生キーや BT ヘッドホン接続で Music.app を起動する
    "com.apple.photoanalysisd" # Photos 未使用
    "com.apple.assistantd" # Siri 無効
    "com.apple.siriknowledged" # Siri 無効
    "com.apple.tipsd" # Tips 未使用
    "com.apple.homed" # Home 未使用
    "com.apple.gamed" # Game Center 未使用
    "com.apple.newsd" # News 未使用
    "com.apple.itunescloudd" # Music / TV の iCloud 同期を使わない
  ];
in
lib.mkIf pkgs.stdenv.isDarwin {
  home.activation.disableAppleAgents = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    uid=$(/usr/bin/id -u)
    for label in ${lib.escapeShellArgs disabled}; do
      run /bin/launchctl disable "gui/$uid/$label"
    done
    # SIP 下では Apple の agent を bootout できないので、disable 済みで再起動されない状態にしてから kill する
    for label in ${lib.escapeShellArgs disabled}; do
      run /usr/bin/pkill -9 -x "''${label#com.apple.}" || true
    done
  '';
}
