{ lib, pkgs, ... }:
let
  sayHookRevision = "6bfb4269a9b626847433f11a1549a1688abcded0";
  sayHookVersion = "v0.4.1";
in
{
  home = {
    file = {
      ".config/herdr/config.toml" = {
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

      ".config/herdr/plugins/config/hikaruegashira.say-hook/.env" = {
        text = ''
          SAY_BIN=$HOME/.local/share/mise/installs/github-hikaru-egashira-say-hook/${sayHookVersion}/say-hook
          ELEVENLABS_VOICE_ID=fUjY9K2nAIwlALOwSiwc
          ELEVENLABS_VOICE_NAME='Yui - Japanese girl female Anime voice'
        '';
        force = true;
      };

      ".config/mise/conf.d/say-hook.toml".text = ''
        [tools]
        "github:HikaruEgashira/say-hook" = "${sayHookVersion}"
      '';
    };

    activation = {
      sayHook = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD "$HOME/.local/bin/mise" unuse --global --no-prune github:HikaruEgashira/say-hook
        $DRY_RUN_CMD "$HOME/.local/bin/mise" install github:HikaruEgashira/say-hook@${sayHookVersion}
      '';

      herdrPlugins = lib.hm.dag.entryAfter [ "sayHook" ] ''
        ${pkgs.gnugrep}/bin/grep -q horn553.herdr-ntfy "$HOME/.config/herdr/plugins.json" 2>/dev/null \
          || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install horn553/herdr-ntfy --ref fd404baffd166863291a1f6ea2067743debdaccf --yes || true

        ${pkgs.jq}/bin/jq -e --arg ref "${sayHookRevision}" \
          '.[] | select(.plugin_id == "hikaruegashira.say-hook" and .source.requested_ref == $ref and .source.resolved_commit == $ref)' \
          "$HOME/.config/herdr/plugins.json" >/dev/null 2>&1 \
          || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install HikaruEgashira/say-hook/herdr --ref ${sayHookRevision} --yes

        $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin action invoke install-claude-hook --plugin hikaruegashira.say-hook
        $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin action invoke check --plugin hikaruegashira.say-hook
      '';
    };
  };
}
