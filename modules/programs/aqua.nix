{
  config,
  lib,
  pkgs,
  ...
}:

let
  aquaConfig = "${config.xdg.configHome}/aqua/aqua.yaml";
  aquaPolicy = "${config.xdg.configHome}/aqua/aqua-policy.yaml";
  aquaRoot = "${config.xdg.dataHome}/aquaproj-aqua";
in
{
  xdg.configFile = {
    "aqua/aqua.yaml".source = ./aqua/aqua.yaml;
    "aqua/aqua-checksums.json".source = ./aqua/aqua-checksums.json;
    "aqua/aqua-policy.yaml".source = ./aqua/aqua-policy.yaml;
    "aqua/registry.yaml".source = ./aqua/registry.yaml;
  };

  home = {
    sessionPath = [ "${aquaRoot}/bin" ];
    sessionVariables = {
      AQUA_GLOBAL_CONFIG = aquaConfig;
      AQUA_POLICY_CONFIG = aquaPolicy;
      AQUA_ENFORCE_CHECKSUM = "true";
      AQUA_ENFORCE_REQUIRE_CHECKSUM = "true";
    };
    activation.installAquaLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      AQUA_GLOBAL_CONFIG=${lib.escapeShellArg aquaConfig} \
      AQUA_POLICY_CONFIG=${lib.escapeShellArg aquaPolicy} \
      AQUA_ROOT_DIR=${lib.escapeShellArg aquaRoot} \
      AQUA_ENFORCE_CHECKSUM=true \
      AQUA_ENFORCE_REQUIRE_CHECKSUM=true \
        run ${pkgs.aqua}/bin/aqua install --only-link --all
      # `install --only-link` は pin から外した package の link を消さない。PATH で ~/.local/bin より前に残ると自己更新版を隠す
      run rm -f ${lib.escapeShellArg "${aquaRoot}/bin/claude"}
    '';
  };
}
