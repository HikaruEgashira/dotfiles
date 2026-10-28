{ lib, ... }:

{
  # /nix が未マウントでも launchd が読めるよう、plist は実ファイルで配置する。
  system.activationScripts.postActivation.text = lib.mkAfter ''
    store_plist=/Library/LaunchDaemons/org.nixos.darwin-store.plist
    if ! /usr/bin/cmp -s ${./nix-store.plist} "$store_plist"; then
      /usr/bin/install -o root -g wheel -m 644 ${./nix-store.plist} "$store_plist" || exit 1
      /bin/launchctl bootout system/org.nixos.darwin-store 2>/dev/null || true
    fi
    /bin/launchctl print system/org.nixos.darwin-store >/dev/null 2>&1 ||
      /bin/launchctl bootstrap system "$store_plist"
  '';

  nix = {
    enable = true;
    nrBuildUsers = 32;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@admin" ];
      substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
