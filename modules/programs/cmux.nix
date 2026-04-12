{
  home.file.".config/cmux/settings.json" = {
    text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
      schemaVersion = 1;

      workspaceColors = {
        selectionColor = "#33467c";
        notificationBadgeColor = "#7aa2f7";
      };

      sidebarAppearance = {
        matchTerminalBackground = true;
        darkModeTintColor = "#1a1b26";
        tintOpacity = 0.5;
      };
    };
    force = true;
  };
}
