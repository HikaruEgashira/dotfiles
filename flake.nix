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
      home-manager,
      treefmt-nix,
      herdr,
      ...
    }:
    let
      overlays = [
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

      mkConfig =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs.dotfilesPath = self;
          modules = [
            ./home.nix
            ./hosts/hikae
          ];
        };

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
          # prettier escapes literal `DI_*` / `PVTI_*` as markdown emphasis;
          # AGENTS.md's agentops marker region is machine-rewritten
          settings.formatter.prettier.excludes = [
            "AGENTS.md"
            "modules/programs/claude/CLAUDE.md"
            # lazy.nvim rewrites these on every :Lazy sync; formatting them fights the tool
            "modules/programs/nvim/config/*.json"
          ];
        };

      lintAppFor =
        system:
        let
          pkgs = pkgsFor system;
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
          pkgs = pkgsFor system;
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
            echo "Entries (purpose / source / name / reason):"
            # awk: `column` is util-linux only, not in coreutils
            printf '%s' "$JSON" \
              | ${pkgs.jq}/bin/jq -r 'sort_by(.purpose, .name) | .[] | [.purpose, .source, .name, .reason] | @tsv' \
              | ${pkgs.gawk}/bin/awk -F'\t' '{ printf "  %-8s %-9s %-32s %s\n", $1, $2, $3, $4 }'
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
          pkgs = pkgsFor system;
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
      updateAppFor =
        system:
        let
          pkgs = pkgsFor system;
          script = pkgs.writeShellScriptBin "update" ''
            set -eu
            root="''${PRJ_ROOT:-$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/dotfiles")}"
            cd "$root"

            activate=0
            for arg in "$@"; do
              case "$arg" in
                --activate) activate=1 ;;
                *) echo "unknown argument: $arg" >&2; exit 1 ;;
              esac
            done

            echo "==> bumping all inputs to latest"
            ${pkgs.nix}/bin/nix flake update

            echo
            echo "==> changed inputs:"
            ${pkgs.git}/bin/git diff --stat -- flake.lock || true

            echo
            echo "==> eval gate"
            ${pkgs.nix}/bin/nix eval --raw .#homeConfigurations.hikae.activationPackage.drvPath > /dev/null

            echo
            echo "==> pi: $(${pkgs.nix}/bin/nix eval --raw .#homeConfigurations.hikae.pkgs.pi-coding-agent.version)"

            if [ "$activate" -eq 0 ]; then
              echo
              echo "Done — flake.lock updated. Apply with: nix run .#update -- --activate"
              exit 0
            fi

            echo
            echo "==> activate: applying new generation"
            ${pkgs.nix}/bin/nix run .#homeConfigurations.hikae.activationPackage
          '';
        in
        {
          type = "app";
          program = "${script}/bin/update";
        };
    in
    {
      homeConfigurations.hikae = mkConfig "aarch64-darwin";

      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system: (treefmtFor system).config.build.wrapper
      );

      apps = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        audit = auditAppFor system;
        lint = lintAppFor system;
        update = updateAppFor system;
      });

      checks.x86_64-linux = {
        build = (mkConfig "x86_64-linux").activationPackage;
        formatting = (treefmtFor "x86_64-linux").config.build.check self;
        mel = melFor "x86_64-linux";
      };
    };
}
