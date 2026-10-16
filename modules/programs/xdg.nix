# XDG base-dir 集約。env を張るだけでは既存 dotdir が残り、ツールが旧パスを
# 作り直すため、activation で一度だけ新パスへ移設する (既存 target は上書きしない)。
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.xdg) cacheHome configHome dataHome;

  # legacy = $HOME 直下の旧パス、target = XDG 側の新パス、env = それを指す変数。
  entries = [
    {
      legacy = ".docker";
      target = "${configHome}/docker";
      env = "DOCKER_CONFIG";
    }
    {
      legacy = ".fly";
      target = "${configHome}/fly";
      env = "FLY_CONFIG_DIR";
    }
    {
      legacy = ".matplotlib";
      target = "${configHome}/matplotlib";
      env = "MPLCONFIGDIR";
    }
    {
      legacy = ".wakatime";
      target = "${configHome}/wakatime";
      env = "WAKATIME_HOME";
    }
    {
      legacy = ".terraformrc";
      target = "${configHome}/terraform/terraformrc";
      env = "TF_CLI_CONFIG_FILE";
    }
    {
      legacy = ".ansible";
      target = "${dataHome}/ansible";
      env = "ANSIBLE_HOME";
    }
    {
      legacy = ".bun";
      target = "${dataHome}/bun";
      env = "BUN_INSTALL";
    }
    {
      legacy = ".bundle";
      target = "${dataHome}/bundler";
      env = "BUNDLE_USER_HOME";
    }
    {
      legacy = ".cocoapods";
      target = "${dataHome}/cocoapods";
      env = "CP_HOME_DIR";
    }
    {
      legacy = "go";
      target = "${dataHome}/go";
      env = "GOPATH";
    }
    {
      legacy = ".rustup";
      target = "${dataHome}/rustup";
      env = "RUSTUP_HOME";
    }
    {
      legacy = ".npm";
      target = "${cacheHome}/npm";
      env = "NPM_CONFIG_CACHE";
    }
  ];

  relocations = lib.concatMapStrings (e: ''
    if [ -e "$HOME/${e.legacy}" ] && [ ! -e "${e.target}" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${builtins.dirOf e.target}"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$HOME/${e.legacy}" "${e.target}"
    elif [ -e "$HOME/${e.legacy}" ]; then
      echo "xdgRelocate: ${e.legacy} と ${e.target} が両方存在、移設を skip" >&2
    fi
  '') entries;
in
{
  xdg.enable = true;

  home.sessionVariables = (lib.listToAttrs (map (e: lib.nameValuePair e.env e.target) entries)) // {
    TF_PLUGIN_CACHE_DIR = "${cacheHome}/terraform/plugin-cache";
  };

  home.activation.xdgRelocate = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    set -eu
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${cacheHome}/terraform/plugin-cache"
    ${relocations}
  '';
}
