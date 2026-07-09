{ pkgs, ... }:
{
  home.file.".config/herdr/config.toml" = {
    text = ''
      onboarding = false

      [ui]
      show_agent_labels_on_pane_borders = false
      agent_panel_sort = "spaces"

      [experimental]
      pane_history = true
      switch_ascii_input_source_in_prefix = true

      [theme]
      name = "catppuccin"
      auto_switch = false
    '';
    force = true;
  };

  home.activation.herdrPlugins = ''
    ${pkgs.gnugrep}/bin/grep -q horn553.herdr-ntfy "$HOME/.config/herdr/plugins.json" 2>/dev/null \
      || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install horn553/herdr-ntfy --ref fd404baffd166863291a1f6ea2067743debdaccf --yes || true

    ${pkgs.gnugrep}/bin/grep -q hikaruegashira.say "$HOME/.config/herdr/plugins.json" 2>/dev/null \
      || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install HikaruEgashira/say/herdr --ref 17f1955c51d6922ad0ce609ce00b0ab0c7fc2b79 --yes || true
  '';
}
