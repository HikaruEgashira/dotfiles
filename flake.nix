{
  description = "Home manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
  let
    username = "hikae";
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./home.nix ];
    };

    apps.${system}.home-manager = {
      type = "app";
      program = "${pkgs.writeShellScriptBin "home-manager" ''
        export FLAKE="''${FLAKE:-.}"
        exec ${home-manager.packages.${system}.home-manager}/bin/home-manager \
          --flake "$FLAKE#${username}" \
          "$@"
      ''}/bin/home-manager";
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [ home-manager nix ];
    };
  };
}
