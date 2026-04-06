{
  description = "hikae's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      forSystem = system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
        };
    in
    {
      homeConfigurations."hikae" = forSystem "aarch64-darwin";

      # CI (ubuntu) での検証用
      checks.x86_64-linux.build =
        (forSystem "x86_64-linux").activationPackage;
    };
}
