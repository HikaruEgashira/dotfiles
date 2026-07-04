{
  description = "hikae's dotfiles";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-pi.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-pi,
      home-manager,
      treefmt-nix,
      herdr,
      ...
    }:
    let
      overlays = [
        (
          final: _prev:
          let
            piPkgs = import nixpkgs-pi {
              system = final.stdenv.hostPlatform.system;
              config.allowUnfree = true;
            };
          in
          {
            pi-coding-agent = piPkgs.pi-coding-agent;
          }
        )
        (final: _prev: {
          herdr = herdr.packages.${final.stdenv.hostPlatform.system}.default;
        })
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

      hosts = {
        hikae = {
          system = "aarch64-darwin";
        };
      };

      forHost =
        host:
        { system, ... }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = {
            dotfilesPath = self;
            inherit host;
          };
          modules = [
            ./home.nix
            ./hosts/${host}
          ];
        };

      forSystem = system: forHost "hikae" { inherit system; };

      treefmtFor =
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            prettier.enable = true;
            shfmt.enable = true;
          };
          settings.formatter.prettier.includes = [
            "*.md"
            "*.yaml"
            "*.yml"
            "*.json"
          ];
        };

      lintAppFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
          script = pkgs.writeShellScriptBin "lint" ''
            set -eu
            root="''${PRJ_ROOT:-$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
            cd "$root"

            echo "==> statix check (config: statix.toml)"
            ${pkgs.statix}/bin/statix check .

            echo "==> deadnix"
            ${pkgs.deadnix}/bin/deadnix --fail .

            echo "==> shellcheck (tracked *.sh)"
            shfiles=$(${pkgs.git}/bin/git ls-files '*.sh' 2>/dev/null || true)
            if [ -n "$shfiles" ]; then
              # shellcheck disable=SC2086
              ${pkgs.shellcheck}/bin/shellcheck $shfiles
            else
              echo "  (no *.sh tracked)"
            fi

            echo "OK: all linters passed"
          '';
        in
        {
          type = "app";
          program = "${script}/bin/lint";
        };

      auditAppFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
          ledger = import ./lib/ledger.nix { lib = pkgs.lib; };
          registry = import ./lib/package-registry.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          payload = ledger.toJSON registry.all;
          script = pkgs.writeShellScriptBin "audit" ''
            set -eu
            JSON=${pkgs.lib.escapeShellArg payload}
            echo "## Package Ledger ($(${pkgs.coreutils}/bin/date -u +%FT%TZ))"
            echo ""
            echo "Total entries: $(printf '%s' "$JSON" | ${pkgs.jq}/bin/jq 'length')"
            echo ""
            echo "By purpose:"
            printf '%s' "$JSON" | ${pkgs.jq}/bin/jq -r 'group_by(.purpose) | .[] | "  \(.[0].purpose)\t\(length)"'
            echo ""
            echo "Entries (purpose / source / expires / name / reason):"
            # awk: `column` is util-linux only, not in coreutils
            printf '%s' "$JSON" \
              | ${pkgs.jq}/bin/jq -r 'sort_by(.purpose, .name) | .[] | [.purpose, .source, (.expires // "-"), .name, .reason] | @tsv' \
              | ${pkgs.gawk}/bin/awk -F'\t' '{ printf "  %-8s %-9s %-11s %-32s %s\n", $1, $2, $3, $4, $5 }'
            echo ""
            EXPIRED=$(printf '%s' "$JSON" | ${pkgs.jq}/bin/jq '[.[] | select(.expires != null)] | length')
            echo "Entries with expires set: $EXPIRED"
          '';
        in
        {
          type = "app";
          program = "${script}/bin/audit";
        };
      # MEL: minimum closure that must always build (CI gate)
      melFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
        in
        pkgs.linkFarmFromDrvs "hikae-mel-${system}" (
          with pkgs;
          [
            git
            gh
            ripgrep
            fd
            jq
            jj
            zsh
            tmux
            gnupg
            coreutils
          ]
        );
    in
    {
      homeConfigurations = nixpkgs.lib.mapAttrs forHost hosts;

      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system: (treefmtFor system).config.build.wrapper
      );

      apps = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        audit = auditAppFor system;
        lint = lintAppFor system;
      });

      checks.x86_64-linux = {
        build = (forSystem "x86_64-linux").activationPackage;
        formatting = (treefmtFor "x86_64-linux").config.build.check self;
        mel = melFor "x86_64-linux";
      };
    };
}
