{ lib, pkgs, ... }:
let
  sayHookRevision = "1a2e8625f019e6be59802a26f5eeec4a9ae3eee0";
  sayHookVersion = "v0.5.1";
  sayHookBinPath = ".local/share/mise/installs/github-hikaru-egashira-say-hook/${sayHookVersion}/say-hook";
  sayHookVoiceId = "fUjY9K2nAIwlALOwSiwc";
  sayHookVoiceName = "Yui - Japanese girl female Anime voice";

  herdrConfigSeed = pkgs.writeText "herdr-config.toml" ''
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

  sayHookEnvSeed = pkgs.writeText "say-hook.env" ''
    SAY_BIN="$HOME/${sayHookBinPath}"
    ELEVENLABS_VOICE_ID=${lib.escapeShellArg sayHookVoiceId}
    ELEVENLABS_VOICE_NAME=${lib.escapeShellArg sayHookVoiceName}
  '';
in
{
  home = {
    file.".config/mise/conf.d/say-hook.toml".text = ''
      [tools]
      "github:HikaruEgashira/say-hook" = "${sayHookVersion}"
    '';

    activation = {
      sayHook = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD "$HOME/.local/bin/mise" unuse --global --no-prune github:HikaruEgashira/say-hook
        $DRY_RUN_CMD "$HOME/.local/bin/mise" install github:HikaruEgashira/say-hook@${sayHookVersion}
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/env \
          ELEVENLABS_VOICE_ID=${lib.escapeShellArg sayHookVoiceId} \
          ELEVENLABS_VOICE_NAME=${lib.escapeShellArg sayHookVoiceName} \
          "$HOME/${sayHookBinPath}" check
      '';

      # Seed のみ。herdr GUI からの保存を潰さないよう、既存ファイルは上書きしない。
      herdrSeed = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -e "$HOME/.config/herdr/config.toml" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -D -m 0644 ${herdrConfigSeed} "$HOME/.config/herdr/config.toml"
        fi
        if [ ! -e "$HOME/.config/herdr/plugins/config/hikaruegashira.say-hook/.env" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -D -m 0644 ${sayHookEnvSeed} "$HOME/.config/herdr/plugins/config/hikaruegashira.say-hook/.env"
        fi
      '';

      herdrPlugins = lib.hm.dag.entryAfter [ "sayHook" "herdrSeed" ] ''
        ${pkgs.gnugrep}/bin/grep -q horn553.herdr-ntfy "$HOME/.config/herdr/plugins.json" 2>/dev/null \
          || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install horn553/herdr-ntfy --ref fd404baffd166863291a1f6ea2067743debdaccf --yes || true

        ${pkgs.jq}/bin/jq -e --arg ref "${sayHookRevision}" \
          '.[] | select(.plugin_id == "hikaruegashira.say-hook" and .source.requested_ref == $ref and .source.resolved_commit == $ref)' \
          "$HOME/.config/herdr/plugins.json" >/dev/null 2>&1 \
          || PATH="${pkgs.git}/bin:$PATH" $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install HikaruEgashira/say-hook/herdr --ref ${sayHookRevision} --yes

        # herdr は disabled プラグインの action を exit 1 で拒否するため、有効時のみ invoke する
        ${pkgs.jq}/bin/jq -e '.[] | select(.plugin_id == "hikaruegashira.say-hook" and .enabled)' "$HOME/.config/herdr/plugins.json" >/dev/null 2>&1 \
          && $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin action invoke install-claude-hook --plugin hikaruegashira.say-hook \
          || true
      '';
    };
  };
}
