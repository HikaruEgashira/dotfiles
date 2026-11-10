{
  config,
  lib,
  pkgs,
  ...
}:

let
  aquaBin = "${config.xdg.dataHome}/aquaproj-aqua/bin";
  # DELL の VCP 0x60 入力コード
  hdmi1 = "17";
  hdmi2 = "18";
in
lib.mkIf pkgs.stdenv.isDarwin {
  launchd.agents.nuphy-kvm-switch = {
    enable = true;
    config = {
      Label = "dev.egahika.nuphy-kvm-switch";
      # モニタの HDMI1 に繋がるのは Mac Studio だけなので、他ホストでは正常終了して KeepAlive を止める
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''[ "$(/usr/sbin/scutil --get LocalHostName)" = Mac-Studio ] || exit 0; exec kvm-switch --connect ${hdmi1} --disconnect ${hdmi2}''
      ];
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${aquaBin}:${pkgs.aqua}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      }
      // lib.filterAttrs (k: _: lib.hasPrefix "AQUA_" k) config.home.sessionVariables;
      StandardOutPath = "${config.home.homeDirectory}/.cache/nuphy-kvm-switch.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/nuphy-kvm-switch.log";
    };
  };

  # Caps 単押し (F13) でカーソルパッドを出す。Accessibility 許可が要る
  launchd.agents.nuphy-snap = {
    enable = true;
    config = {
      Label = "dev.egahika.nuphy-snap";
      ProgramArguments = [ "${aquaBin}/snap" ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${aquaBin}:${pkgs.aqua}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      }
      // lib.filterAttrs (k: _: lib.hasPrefix "AQUA_" k) config.home.sessionVariables;
      StandardOutPath = "${config.home.homeDirectory}/.cache/nuphy-snap.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/nuphy-snap.log";
    };
  };
}
