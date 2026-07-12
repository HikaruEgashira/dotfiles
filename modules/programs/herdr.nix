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

    ${pkgs.gnugrep}/bin/grep -q hikaruegashira.say-hook "$HOME/.config/herdr/plugins.json" 2>/dev/null \
      || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install HikaruEgashira/say-hook/herdr --ref bcaa40b7d7c7c6382a749de8afc21a866348392b --yes || true
  '';
}
