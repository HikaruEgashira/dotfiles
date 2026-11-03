{ lib, ... }:

let
  # 自動再起動は常駐 agent を無警告で落とすので download までに留め、適用は docs/operations.md 7.1 の手動 window で行う
  softwareUpdate = {
    AutomaticCheckEnabled = true;
    AutomaticDownload = true;
    AutomaticallyInstallMacOSUpdates = false;
    CriticalUpdateInstall = true;
  };
in
{
  system = {
    stateVersion = 6;

    # nix-darwin の defaults 系オプションはこのユーザーを対象にする
    primaryUser = "hikae";

    # CustomSystemPreferences は root の ~/Library/Preferences に書き、実効値の /Library/Preferences には届かないため、plist path を明示して書く
    activationScripts.postActivation.text = lib.mkAfter ''
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          k: v:
          "defaults write /Library/Preferences/com.apple.SoftwareUpdate ${k} -bool ${lib.boolToString v}"
        ) softwareUpdate
      )}
    '';
  };

  # 既存 account の uid/home と一致させ、activation の dscl が何も変更しないようにする
  users.users.hikae = {
    name = "hikae";
    uid = 501;
    home = "/Users/hikae";
  };
}
