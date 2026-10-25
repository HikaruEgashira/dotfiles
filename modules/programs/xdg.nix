# XDG 集約: 既存 dotdir は activation で 1 度だけ移設し、target が既にあれば skip する
{
  config,
  lib,
  pkgs,
  ...
}:
let
  entries =
    (import ../../lib/xdg-entries.nix {
      inherit lib;
      inherit (config.xdg)
        configHome
        cacheHome
        dataHome
        stateHome
        ;
    }).entries;

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
    TF_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/terraform/plugin-cache";
  };

  # TF_CLI_CONFIG_FILE の実体。env を持たない呼び出し (launchd / sandbox) でも同じ cache を使わせ、project 毎に provider が複製されるのを防ぐ
  xdg.configFile."terraform/terraformrc".text = ''
    plugin_cache_dir = "${config.xdg.cacheHome}/terraform/plugin-cache"
  '';

  home.activation.xdgRelocate = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    set -eu
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${config.xdg.cacheHome}/terraform/plugin-cache"
    ${relocations}
  '';
}
