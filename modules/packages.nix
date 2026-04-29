{ pkgs, ... }:

{
  home.packages = [
    # Nix runtime / package mgmt
    pkgs.cachix
    pkgs.pinentry-curses
    pkgs.lato
    pkgs.mise
    pkgs.devenv

    # 既存維持
    pkgs.ghq
    pkgs.gh
    pkgs.ripgrep
    pkgs.fd
    pkgs.gitleaks

    # CI / GitHub Actions
    pkgs.act
    pkgs.actionlint
    pkgs.pinact
    pkgs.wrkflw
    pkgs.github-mcp-server

    # Cloud / Infra / Security
    pkgs.awscli2
    pkgs.aws-sam-cli
    pkgs.cloudflared
    pkgs.flyctl
    pkgs.terraformer
    pkgs.driftctl
    pkgs.checkov
    pkgs.trivy
    pkgs.trufflehog
    pkgs.sops

    # Container / Virt
    pkgs.docker-buildx
    pkgs.podman
    pkgs.qemu
    pkgs.lima
    pkgs.devcontainer

    # Languages / build
    pkgs.cmake
    pkgs.automake
    pkgs.pkg-config
    pkgs.deno
    pkgs.zig
    pkgs.opam
    pkgs.golangci-lint
    pkgs.ast-grep
    pkgs.tree-sitter
    pkgs.wasmtime
    pkgs.sccache
    pkgs.sqlc
    pkgs.cocoapods
    pkgs.dotenvx

    # DB / data
    pkgs.duckdb
    pkgs.postgresql_14
    pkgs.redis

    # CLI utils
    pkgs.coreutils
    pkgs.tree
    pkgs.htop
    pkgs.jq
    pkgs.jj
    pkgs.just
    pkgs.nushell
    pkgs.pueue
    pkgs.rclone
    pkgs.mas
    pkgs.duti
    pkgs.terminal-notifier
    pkgs.iproute2mac
    pkgs.bitwarden-cli
    pkgs.git-lfs
    pkgs.inetutils
    pkgs.sshpass
    pkgs.mosh
    pkgs.nmap
    pkgs.openvpn
    pkgs.ngrok
    pkgs.mitmproxy

    # Media / docs
    pkgs.pandoc
    pkgs.graphviz
    pkgs.marp-cli
    pkgs.vhs
    pkgs.frogmouth
    pkgs.poppler
    pkgs.sox
    pkgs.yt-dlp

    # Reverse / security research
    pkgs.radare2
    pkgs.sn0int

    # Misc
    pkgs.ollama
    # pkgs.mole は nixpkgs で broken。Brewfile 維持
  ];
}
