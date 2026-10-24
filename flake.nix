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
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      nix-darwin,
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

      # linux CI 用: home.nix を aarch64/x86_64-linux で eval し platform mismatch を捕まえる
      mkHome =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs.dotfilesPath = self;
          modules = [
            ./home.nix
          ];
        };

      mkDarwin =
        system:
        nix-darwin.lib.darwinSystem {
          specialArgs.dotfilesPath = self;
          modules = [
            ./hosts/macbook-air/default.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs = {
                hostPlatform = system;
                inherit overlays;
                config.allowUnfree = true;
              };
              system.configurationRevision = self.rev or self.dirtyRev or null;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs.dotfilesPath = self;
                users.hikae = import ./home.nix;
              };
            }
          ];
        };

      # XDG entry の live 定義は darwin では nix-darwin 経由の home-manager が持つ
      xdgConfigFor =
        system:
        let
          hm =
            if system == "aarch64-darwin" then
              (mkDarwin system).config.home-manager.users.hikae
            else
              (mkHome system).config;
        in
        hm.xdg // { launchdAgents = hm.launchd.agents or { }; };

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
      launchdAuditAppFor =
        system:
        let
          pkgs = pkgsFor system;
          lib = pkgs.lib;
          hmLabels = lib.mapAttrsToList (_: a: a.config.Label) (
            lib.filterAttrs (_: a: a.enable) (xdgConfigFor system).launchdAgents
          );
          script = pkgs.writeShellScriptBin "launchd-audit" ''
            set -eu
            if [ "$(${pkgs.coreutils}/bin/uname -s)" != "Darwin" ]; then
              echo "launchd-audit: macOS only; skipping"
              exit 0
            fi

            # home-manager が宣言する label は config から導出し、vendor の自己管理 agent だけを手書きする
            known='
            ${lib.concatStringsSep "\n            " hmLabels}
            com.atlassian.twg.upkeep
            com.opencodex.proxy
            com.google.GoogleUpdater.wake
            com.openai.codex-sparkle-progress
            com.openai.codex-sparkle-updater
            com.openssh.ssh-agent
            io.tailscale.ipn.macsys.login-item-helper
            jp.kiok.nani.ShipIt
            '

            echo "## launchd third-party agents ($(${pkgs.coreutils}/bin/date -u +%FT%TZ))"
            echo ""

            labels=$(/bin/launchctl list \
              | ${pkgs.gawk}/bin/awk 'NR>1 {print $NF}' \
              | ${pkgs.gnugrep}/bin/grep -vE '^(com\.apple\.|application\.)' \
              | ${pkgs.coreutils}/bin/sort -u || true)

            unknown=""
            while IFS= read -r label; do
              [ -n "$label" ] || continue
              if ! printf '%s\n' "$known" | ${pkgs.gnugrep}/bin/grep -qxF "$label"; then
                unknown="''${unknown}  UNKNOWN  ''${label}\n"
              fi
            done <<EOF
            $labels
            EOF

            if [ -n "$unknown" ]; then
              printf '%b' "$unknown"
              echo ""
              echo "declare it in docs/launchd.md or remove it"
              exit 1
            fi
            echo "OK: no unexpected third-party launchd agents"
          '';
        in
        {
          type = "app";
          program = "${script}/bin/launchd-audit";
        };
      xdgAuditAppFor =
        system:
        let
          pkgs = pkgsFor system;
          entries =
            (import ./lib/xdg-entries.nix {
              lib = pkgs.lib;
              inherit (xdgConfigFor system)
                configHome
                cacheHome
                dataHome
                stateHome
                ;
            }).entries;
          manifest = pkgs.writeText "xdg-entries.json" (builtins.toJSON entries);
          script = pkgs.writeShellScriptBin "xdg-audit" ''
            set -eu

            exports=$(${pkgs.coreutils}/bin/env -u __HM_SESS_VARS_SOURCED -u __HM_ZSH_SESS_VARS_SOURCED ${pkgs.zsh}/bin/zsh -lic 'export -p' 2>/dev/null || true)
            drift=""

            report() { printf '  %-9s %-14s %s\n' "$1" "$2" "$3"; }

            echo "## XDG entries ($(${pkgs.coreutils}/bin/date -u +%FT%TZ))"
            echo ""

            while IFS=$'\t' read -r legacy target env override; do
              if [ -e "$HOME/$legacy" ] && [ -e "$target" ]; then
                report DRIFT "~/$legacy" "legacy と target が両方存在 (移設が skip された: $target)"
                drift=1
              elif [ -e "$HOME/$legacy" ]; then
                report PENDING "~/$legacy" "未移設 → activation で $target へ移動する"
              elif [ ! -e "$target" ]; then
                report ABSENT "~/$legacy" "$target は未作成 (対象ツールが未使用なら問題なし)"
              fi

              [ -n "$env" ] || continue
              line=$(${pkgs.gnugrep}/bin/grep -m1 "^export $env=" <<< "$exports" || true)
              if [ -z "$line" ]; then
                report DRIFT "$env" "宣言されているが login shell に export されていない"
                drift=1
                continue
              fi
              value=''${line#"export $env="}
              case "$value" in \'*\') value=''${value#\'}; value=''${value%\'} ;; esac
              if [ "$value" = "$target" ]; then
                report OK "$env" "$value"
              elif [ -n "$override" ]; then
                report OVERRIDE "$env" "$value ($override 所有)"
              else
                report DRIFT "$env" "宣言 $target と live $value が不一致"
                drift=1
              fi
            done < <(${pkgs.jq}/bin/jq -r '.[] | [.legacy, .target, (.env // ""), (.override // "")] | @tsv' ${manifest})

            if [ -n "$drift" ]; then
              echo ""
              echo "drift あり: entries を直すか activation を打ち直す"
              echo "drift=1"
              exit 1
            fi
            echo ""
            echo "OK: XDG entries は宣言どおり"
            echo "drift=0"
          '';
        in
        {
          type = "app";
          program = "${script}/bin/xdg-audit";
        };
      # 各 guard が実際に発火することを強制する (guard を消したら CI が落ちる)
      xdgGuardCheckFor =
        system:
        let
          pkgs = pkgsFor system;
          lib = pkgs.lib;
          inherit (xdgConfigFor system)
            configHome
            cacheHome
            dataHome
            stateHome
            ;
          mkEntry =
            (import ./lib/xdg-entries.nix {
              inherit
                lib
                configHome
                cacheHome
                dataHome
                stateHome
                ;
            }).mkEntry;

          verdict =
            expect: name: entry:
            if (builtins.tryEval (builtins.deepSeq (mkEntry entry) true)).success == expect then
              name
            else
              throw "xdg-entries-guards: '${name}' did not behave as expected";

          cases = [
            (verdict false "absolute legacy" {
              legacy = "/go";
              target = "${dataHome}/go";
              env = "GOPATH";
            })
            (verdict false "parent escape" {
              legacy = "../go";
              target = "${dataHome}/go";
              env = "GOPATH";
            })
            (verdict false "target outside XDG" {
              legacy = "go";
              target = "/etc/evil";
              env = "GOPATH";
            })
            (verdict false "lowercase env" {
              legacy = "go";
              target = "${dataHome}/go";
              env = "gopath";
            })
            (verdict true "valid entry" {
              legacy = "go";
              target = "${dataHome}/go";
              env = "GOPATH";
            })
          ];
        in
        pkgs.runCommand "xdg-entries-guards" { } ''
          cat > $out <<'EOF'
          ${lib.concatStringsSep "\n" cases}
          EOF
        '';
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
            ${pkgs.nix}/bin/nix eval --raw .#darwinConfigurations.hikae.system.drvPath > /dev/null

            if [ "$activate" -eq 0 ]; then
              echo
              echo "Done — flake.lock updated. Apply with: nix run .#switch"
              exit 0
            fi

            echo
            echo "==> activate: applying new generation"
            ${pkgs.nix}/bin/nix run .#switch
          '';
        in
        {
          type = "app";
          program = "${script}/bin/update";
        };
      switchAppFor =
        system:
        let
          pkgs = pkgsFor system;
          darwin-rebuild = nix-darwin.packages.${system}.darwin-rebuild;
          script = pkgs.writeShellScriptBin "switch" ''
            set -eu
            root="''${PRJ_ROOT:-$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/dotfiles")}"
            exec /usr/bin/sudo ${darwin-rebuild}/bin/darwin-rebuild switch --flake "$root#hikae"
          '';
        in
        {
          type = "app";
          program = "${script}/bin/switch";
        };
      darwinEvalCheckFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        builtins.seq (mkDarwin system).system.drvPath (pkgs.runCommand "darwin-eval" { } "touch $out");
    in
    {
      darwinConfigurations.hikae = mkDarwin "aarch64-darwin";

      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (
        system: (treefmtFor system).config.build.wrapper
      );

      apps = nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (
        system:
        {
          audit = auditAppFor system;
          launchd-audit = launchdAuditAppFor system;
          lint = lintAppFor system;
          update = updateAppFor system;
          xdg-audit = xdgAuditAppFor system;
        }
        // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
          switch = switchAppFor system;
        }
      );

      checks = {
        aarch64-linux = {
          build = (mkHome "aarch64-linux").activationPackage;
          formatting = (treefmtFor "aarch64-linux").config.build.check self;
          mel = melFor "aarch64-linux";
          "xdg-entries-guards" = xdgGuardCheckFor "aarch64-linux";
        };
        x86_64-linux = {
          build = (mkHome "x86_64-linux").activationPackage;
          formatting = (treefmtFor "x86_64-linux").config.build.check self;
          mel = melFor "x86_64-linux";
          "xdg-entries-guards" = xdgGuardCheckFor "x86_64-linux";
        };
        # ローカルの `nix flake check` でも guard を走らせる (CI は aarch64-linux 側を回す)
        aarch64-darwin = {
          "xdg-entries-guards" = xdgGuardCheckFor "aarch64-darwin";
          "darwin-eval" = darwinEvalCheckFor "aarch64-darwin";
        };
      };
    };
}
