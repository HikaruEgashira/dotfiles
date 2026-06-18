{
  home = {
    username = "hikae";
    homeDirectory = "/Users/hikae";
    stateVersion = "23.11";
    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      GOPRIVATE = "github.com/HikaruEgashira/*,github.com/plenoai/*";
    };

    file.".npmrc" = {
      text = ''
        //npm.pkg.github.com/:_authToken=''${GH_PKG_TOKEN}
        @NAMESPACE:registry=https://npm.pkg.github.com
        //registry.npmjs.org/:_authToken=''${NPM_TOKEN}
        registry=https://npm.flatt.tech/
        //npm.flatt.tech/:_authToken=''${FLATT_GUARD_TOKEN}
        allow-git=none
        allow-remote=none
        allow-file=none
        allow-directory=none
        min-release-age=3
        audit-level=high
      '';
      force = true;
    };
    # pnpm reads its own global rc; keeping these out of ~/.npmrc avoids
    # npm 11 warnings (and npm 12 errors) on unknown user config.
    file."Library/Preferences/pnpm/rc" = {
      text = ''
        minimum-release-age=4320
        trust-policy=no-downgrade
        strict-dep-builds=true
      '';
      force = true;
    };
  };
}
