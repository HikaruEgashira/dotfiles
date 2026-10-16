{
  lib,
  configHome,
  cacheHome,
  dataHome,
  stateHome,
}:

let
  roots = [
    configHome
    cacheHome
    dataHome
    stateHome
  ];

  mkEntry =
    {
      legacy,
      target,
      env,
      override ? null,
    }:
    assert lib.assertMsg (
      !lib.hasPrefix "/" legacy && legacy != "" && !(lib.hasInfix ".." legacy)
    ) "xdg.mkEntry: legacy must be a \$HOME-relative path, got '${legacy}'";
    assert lib.assertMsg (lib.any (
      r: lib.hasPrefix "${r}/" target
    ) roots) "xdg.mkEntry: target must be under an XDG root, got '${target}'";
    assert lib.assertMsg (
      builtins.match "[A-Z][A-Z0-9_]*" env != null
    ) "xdg.mkEntry: env must be an uppercase identifier, got '${env}'";
    {
      inherit
        legacy
        target
        env
        override
        ;
    };

  entries = [
    (mkEntry {
      legacy = ".docker";
      target = "${configHome}/docker";
      env = "DOCKER_CONFIG";
    })
    (mkEntry {
      legacy = ".fly";
      target = "${configHome}/fly";
      env = "FLY_CONFIG_DIR";
    })
    (mkEntry {
      legacy = ".matplotlib";
      target = "${configHome}/matplotlib";
      env = "MPLCONFIGDIR";
    })
    (mkEntry {
      legacy = ".wakatime";
      target = "${configHome}/wakatime";
      env = "WAKATIME_HOME";
    })
    (mkEntry {
      legacy = ".terraformrc";
      target = "${configHome}/terraform/terraformrc";
      env = "TF_CLI_CONFIG_FILE";
    })
    (mkEntry {
      legacy = ".ansible";
      target = "${dataHome}/ansible";
      env = "ANSIBLE_HOME";
    })
    (mkEntry {
      legacy = ".bun";
      target = "${dataHome}/bun";
      env = "BUN_INSTALL";
    })
    (mkEntry {
      legacy = ".bundle";
      target = "${dataHome}/bundler";
      env = "BUNDLE_USER_HOME";
    })
    (mkEntry {
      legacy = ".cocoapods";
      target = "${dataHome}/cocoapods";
      env = "CP_HOME_DIR";
    })
    (mkEntry {
      legacy = "go";
      target = "${dataHome}/go";
      env = "GOPATH";
    })
    (mkEntry {
      legacy = ".rustup";
      target = "${dataHome}/rustup";
      env = "RUSTUP_HOME";
      override = "mise";
    })
    (mkEntry {
      legacy = ".npm";
      target = "${cacheHome}/npm";
      env = "NPM_CONFIG_CACHE";
    })
  ];

  envNames = map (e: e.env) entries;
in
assert lib.assertMsg (
  lib.length (lib.unique (map (e: e.legacy) entries)) == lib.length entries
) "xdg.entries: duplicate legacy path";
assert lib.assertMsg (
  lib.length (lib.unique (map (e: e.target) entries)) == lib.length entries
) "xdg.entries: duplicate target path";
assert lib.assertMsg (
  lib.length (lib.unique envNames) == lib.length envNames
) "xdg.entries: duplicate env name";
{
  inherit entries;
}
