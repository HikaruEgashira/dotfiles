{
  home = {
    username = "hikae";
    homeDirectory = "/Users/hikae";
    stateVersion = "23.11";
    enableNixpkgsReleaseCheck = false;

    file.".npmrc" = {
      text = ''
        //npm.pkg.github.com/:_authToken=''${GH_PKG_TOKEN}
        @NAMESPACE:registry=https://npm.pkg.github.com
        //registry.npmjs.org/:_authToken=''${NPM_TOKEN}
        registry=https://npm.flatt.tech/
        //npm.flatt.tech/:_authToken=''${FLATT_GUARD_TOKEN}
      '';
      force = true;
    };
  };
}
