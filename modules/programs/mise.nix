{ ... }:

{
  # Checkouts live under ~/ghq; trust by path so new clones never trip trust prompts.
  home.file.".config/mise/conf.d/trust.toml".text = ''
    [settings]
    trusted_config_paths = [ "~/ghq" ]
  '';

  home.file.".local/bin/mise-trust-repo" = {
    text = builtins.readFile ./mise/trust-repo.sh;
    executable = true;
  };
}
