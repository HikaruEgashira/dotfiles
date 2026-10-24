_:

{
  system = {
    stateVersion = 6;

    # nix-darwin の defaults 系オプションはこのユーザーを対象にする
    primaryUser = "hikae";

    # docs/operations.md にあった 3 つの `sudo defaults write` の置き換え
    defaults.CustomSystemPreferences."com.apple.SoftwareUpdate" = {
      AutomaticDownload = true;
      AutomaticallyInstallMacOSUpdates = true;
      CriticalUpdateInstall = true;
    };
  };

  # 既存 account の uid/home と一致させ、activation の dscl が何も変更しないようにする
  users.users.hikae = {
    name = "hikae";
    uid = 501;
    home = "/Users/hikae";
  };
}
