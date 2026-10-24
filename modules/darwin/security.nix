{ lib, ... }:

{
  # ALF の非必須受信を遮断し、忘れた dev server の *:PORT bind を LAN から通常到達不能にする
  networking.applicationFirewall = {
    enable = true;
    blockAllIncoming = true;
    enableStealthMode = true;
  };

  # nix-darwin は設定を書くだけで読み戻さないので、この script で適用結果を検証する
  system.activationScripts.networking.text = lib.mkAfter ''
    actual=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode --getblockall 2>&1) || {
      echo "ERROR: firewall posture could not be read back" >&2
      exit 1
    }
    if [[ "$actual" == *"(State = 1)"* || "$actual" == *"(State = 2)"* ]] &&
      [[ "$actual" == *"stealth mode is on"* ]] &&
      [[ "$actual" == *"blocking all non-essential incoming connections"* ]]; then
      echo "firewall: global+stealth+blockall verified" >&2
    else
      echo "ERROR: firewall posture verification failed" >&2
      echo "$actual" >&2
      exit 1
    fi
  '';

  # tmux 内の sudo でも Touch ID が効くよう reattach を併用する
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Wi-Fi service の静的 DNS は DHCP (gateway の encrypted DNS) と DoH profile を迂回して平文 53 を ISP に傍受させるので常に空に保つ
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if /usr/sbin/networksetup -getdnsservers Wi-Fi 2>/dev/null | grep -q '^[0-9a-f:.]*$'; then
      /usr/sbin/networksetup -setdnsservers Wi-Fi Empty
      echo "wifi-dns: static resolvers cleared, DHCP is authoritative" >&2
    fi
  '';
}
