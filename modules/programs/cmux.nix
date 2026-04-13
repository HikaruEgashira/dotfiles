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
        selectionColor = "#33467c";
        notificationBadgeColor = "#7aa2f7";
      };

      sidebarAppearance = {
        matchTerminalBackground = true;
        tintColor = "#000000";
        darkModeTintColor = "#1a1b26";
        tintOpacity = 0.5;
      };
    };
    force = true;
  };

  # plist-only settings (not available in settings.json schema)
  home.activation.cmuxDefaults = ''
    /usr/bin/defaults write com.cmuxterm.app sidebarBlendMode -string "withinWindow"
    /usr/bin/defaults write com.cmuxterm.app sidebarBlurOpacity -float 1
    /usr/bin/defaults write com.cmuxterm.app sidebarCornerRadius -float 0
    /usr/bin/defaults write com.cmuxterm.app sidebarMaterial -string "sidebar"
    /usr/bin/defaults write com.cmuxterm.app sidebarPreset -string "nativeSidebar"
    /usr/bin/defaults write com.cmuxterm.app sidebarState -string "followWindow"
  '';
}
