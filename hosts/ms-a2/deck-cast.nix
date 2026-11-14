# ccdeck を Chromecast (TV) に常時表示する。TV の古い Chrome は deck の JS を動かせないので headless Chromium の画面を画像で渡す
{ pkgs, ... }:
let
  # DHCP 予約で固定している前提。変わったら proxy の許可と caster の宛先がまとめて外れる
  chromecast = "192.168.1.148";
  lanAddr = "192.168.1.91";
  port = 14318;
  common = {
    User = "hikae";
    Restart = "always";
    RestartSec = 10;
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = "read-only";
    PrivateTmp = true;
  };
in
{
  systemd.services.deck-cast-proxy = {
    description = "ccdeck snapshots for the Chromecast";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      DECK_CAST_PORT = toString port;
      DECK_CAST_ALLOW = chromecast;
      DECK_CAST_CHROMIUM = "${pkgs.chromium}/bin/chromium";
      # chromium は ~/.pki 等を書くので PrivateTmp 内を HOME にする
      HOME = "/tmp";
    };
    serviceConfig = common // {
      ExecStart = "${pkgs.nodejs}/bin/node ${./deck-cast}/proxy.mjs";
    };
  };

  systemd.services.deck-cast = {
    description = "Keep ccdeck on the Chromecast while it is idle";
    wantedBy = [ "multi-user.target" ];
    after = [ "deck-cast-proxy.service" ];
    environment = {
      DECK_CAST_DEVICE = chromecast;
      DECK_CAST_URL = "http://${lanAddr}:${toString port}/";
    };
    serviceConfig = common // {
      ExecStart = "${pkgs.nodejs}/bin/node ${./deck-cast}/caster.mjs";
    };
  };

  # LAN 全体ではなく Chromecast からの受信だけを開ける
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s ${chromecast} --dport ${toString port} -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp -s ${chromecast} --dport ${toString port} -j nixos-fw-accept || true
  '';
}
