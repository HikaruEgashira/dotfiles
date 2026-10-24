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

  # home-manager.users が homeDirectory を読むためだけの宣言。既存 account の uid/home と一致させ、
  # 変更が起きないようにする (dscl は uid 不一致のときだけ動く)
  users.users.hikae = {
    name = "hikae";
    uid = 501;
    home = "/Users/hikae";
  };
}
