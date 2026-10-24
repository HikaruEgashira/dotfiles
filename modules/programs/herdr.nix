{
  config,
  lib,
  pkgs,
  ...
}:
let
  registry = import ../../lib/package-registry.nix { inherit pkgs lib; };
  sayHookRevision = "1a2e8625f019e6be59802a26f5eeec4a9ae3eee0";
  sayHookBin = if registry.sayHook == null then "" else "${registry.sayHook}/bin/say-hook";
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
    SAY_BIN=${lib.escapeShellArg sayHookBin}
    ELEVENLABS_VOICE_ID=${lib.escapeShellArg sayHookVoiceId}
    ELEVENLABS_VOICE_NAME=${lib.escapeShellArg sayHookVoiceName}
  '';
in
{
  home = {
    activation = {
      sayHook = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/env \
            ELEVENLABS_VOICE_ID=${lib.escapeShellArg sayHookVoiceId} \
            ELEVENLABS_VOICE_NAME=${lib.escapeShellArg sayHookVoiceName} \
            ${sayHookBin} check
        ''
      );

      # Seed のみ。herdr GUI からの保存を潰さないよう、既存ファイルは上書きしない。
      # SAY_BIN が旧パスを指したままの seed だけは再生成する。
      herdrSeed = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -e "${config.home.homeDirectory}/.config/herdr/config.toml" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -D -m 0644 ${herdrConfigSeed} "${config.home.homeDirectory}/.config/herdr/config.toml"
        fi
        say_hook_env="${config.home.homeDirectory}/.config/herdr/plugins/config/hikaruegashira.say-hook/.env"
        if [ ! -e "$say_hook_env" ] || ${pkgs.gnugrep}/bin/grep -q '^SAY_BIN=.*mise' "$say_hook_env"; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -D -m 0644 ${sayHookEnvSeed} "$say_hook_env"
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
