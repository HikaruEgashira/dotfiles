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

    # LLM token reduction proxy (rtk-ai/rtk)
    pkgs.rtk

    # Misc
    pkgs.ollama
    # pkgs.mole は nixpkgs で broken。Brewfile 維持

    # 追加移行: tap → nixpkgs
    pkgs.crush
    pkgs.wishlist
    pkgs.nextdns
    pkgs.reviewdog
    pkgs.stripe-cli
    pkgs.supabase-cli
    pkgs.tinygo
    pkgs.powerpipe
    pkgs.steampipe

    # Mobile dev (cask 移行)
    pkgs.android-tools

    # GUI applications (cask 移行・darwin 対応確認済み)
    pkgs.vscode
    pkgs.code-cursor
    pkgs.slack
    pkgs.discord
    pkgs.spotify
    pkgs.google-chrome
    pkgs.raycast
    # pkgs.calibre は nixpkgs で broken
    pkgs.bitwarden-desktop

    # build / lib deps (brew leaves に出ていた一般ツール)
    pkgs.ffmpeg
    pkgs.gnupg
    pkgs.librsvg
    pkgs.protobuf
    pkgs.autoconf
    pkgs.gts
  ];
}
