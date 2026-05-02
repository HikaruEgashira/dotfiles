{
  description = "hikae's dotfiles";

  # Trusted substituter — home-manager activation を source build に落とさない。
  # nix-community キーは upstream 配布値、追加時は CI 側でも extra_nix_config に反映。
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
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      treefmt-nix,
      ...
    }:
    let
      # darwin で hang する / cache されない上流テストを止めるための minimal overlay。
      # 個別パッケージにのみ適用 — フル python 系を再ビルドしたくないので overrideAttrs に留める。
      overlays = [
        (_final: prev: {
          # direnv 2.37.1 の test-zsh が aarch64-darwin で stdin 待ちで hang する
          direnv = prev.direnv.overrideAttrs (_: {
            doCheck = false;
          });
        })
      ];

      forSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            dotfilesPath = self;
          };
          modules = [ ./home.nix ];
        };

      treefmtFor =
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.prettier.enable = true;
          programs.shfmt.enable = true;
          settings.formatter.prettier.includes = [
            "*.md"
            "*.yaml"
            "*.yml"
            "*.json"
          ];
        };

      # Package ledger audit script (Survivor #2 MVP).
      # 各 system の pkgs から registry を組み立て、purpose 別の集計と
      # expires 期限切れエントリを STDOUT に出力する。
      auditAppFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
          ledger = import ./lib/ledger.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
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
            # awk で列整形 (column は coreutils に無く util-linux 依存になるため避ける)
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
    in
    {
      homeConfigurations."hikae" = forSystem "aarch64-darwin";

      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system: (treefmtFor system).config.build.wrapper
      );

      apps = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        audit = auditAppFor system;
      });

      # CI (ubuntu) での検証用
      checks.x86_64-linux = {
        build = (forSystem "x86_64-linux").activationPackage;
        formatting = (treefmtFor "x86_64-linux").config.build.check self;
      };
    };
}
