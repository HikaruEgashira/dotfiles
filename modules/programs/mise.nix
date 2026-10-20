{ config, ... }:

{
  home = {
    file = {
      # Checkouts live under ~/ghq; trust by path so new clones never trip trust prompts.
      ".config/mise/conf.d/trust.toml".text = ''
        [settings]
        trusted_config_paths = [ "~/ghq" ]
      '';

      ".local/bin/mise-trust-repo" = {
        text = builtins.readFile ./mise/trust-repo.sh;
        executable = true;
      };
    };

    # conf.d is ignored when XDG_CONFIG_HOME moves, so keep an env fallback that hook subprocesses inherit.
    sessionVariables.MISE_TRUSTED_CONFIG_PATHS = "${config.home.homeDirectory}/ghq";
  };
}
