{
  home.file.".config/cmux/settings.json" = {
    text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
      schemaVersion = 1;

      app = {
        appearance = "dark";
        newWorkspacePlacement = "afterCurrent";
        warnBeforeQuit = false;
      };

      workspaceColors = {
        selectionColor = "#283457";
        notificationBadgeColor = "#7aa2f7";
      };

      sidebarAppearance = {
        matchTerminalBackground = true;
        tintColor = "#1a1b26";
        darkModeTintColor = "#1a1b26";
        tintOpacity = 0.5;
      };
    };
    force = true;
  };

  # plist-only settings (not available in settings.json schema)
  home.activation.cmuxDefaults = ''
    /usr/bin/defaults write com.cmuxterm.app sidebarBlendMode -string "withinWindow"
    /usr/bin/defaults write com.cmuxterm.app sidebarBlurOpacity -float 0
    /usr/bin/defaults write com.cmuxterm.app sidebarCornerRadius -float 0
    /usr/bin/defaults write com.cmuxterm.app sidebarMaterial -string "sidebar"
    /usr/bin/defaults write com.cmuxterm.app sidebarPreset -string "nativeSidebar"
    /usr/bin/defaults write com.cmuxterm.app sidebarState -string "followWindow"
    /usr/bin/defaults write com.cmuxterm.app sidebarTintHex -string "#1A1B26"
    /usr/bin/defaults write com.cmuxterm.app sidebarTintHexDark -string "#1A1B26"
    /usr/bin/defaults write com.cmuxterm.app sidebarSelectionColorHex -string "#283457"
    /usr/bin/defaults write com.cmuxterm.app sidebarNotificationBadgeColorHex -string "#7AA2F7"
    /usr/bin/defaults write com.cmuxterm.app sidebarMatchTerminalBackground -bool true
    /usr/bin/defaults write com.cmuxterm.app browserThemeMode -string "system"
    /usr/bin/defaults write com.cmuxterm.app notificationSound -string "Pop"
    /usr/bin/defaults write com.cmuxterm.app preferredEditorCommand -string "zed"
    /usr/bin/defaults write com.cmuxterm.app sendAnonymousTelemetry -bool false
    /usr/bin/defaults write com.cmuxterm.app workspacePresentationMode -string "minimal"
  '';
}
