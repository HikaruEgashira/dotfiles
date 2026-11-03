_:

{
  system = {
    stateVersion = 6;

    # nix-darwin の defaults 系オプションはこのユーザーを対象にする
    primaryUser = "hikae";

    # 自動再起動は常駐 agent を無警告で落とすので download までに留め、適用は docs/operations.md 7.1 の手動 window で行う
    defaults.CustomSystemPreferences."com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      AutomaticDownload = true;
      AutomaticallyInstallMacOSUpdates = false;
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
