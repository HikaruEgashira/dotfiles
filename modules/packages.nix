{ pkgs, lib, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  # darwin でしかビルドできない / linux 等価が無いもの。
  # CI は x86_64-linux で評価するためここを越境させると build 失敗。
  darwinOnly = lib.optionals isDarwin [
    pkgs.cocoapods
    pkgs.mas
    pkgs.duti
    pkgs.terminal-notifier
    pkgs.iproute2mac
    pkgs.raycast
  ];

  cross = [
    # Nix runtime / package mgmt
    pkgs.cachix
    pkgs.pinentry-curses
    pkgs.lato
    pkgs.mise
    pkgs.devenv

    # Devflow
    pkgs.gh
    pkgs.ripgrep
    pkgs.fd
    pkgs.gitleaks
    pkgs.pinact

    # Cloud / Infra / Security
    pkgs.awscli2
    pkgs.cloudflared
    pkgs.flyctl
    # pkgs.checkov: nixpkgs ≥ 2026-04-27 で python313Packages.av の
    # pythonImportsCheck が aarch64-darwin で SIGKILL → Brewfile に逃がす
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
    pkgs.golangci-lint
    pkgs.ast-grep
    pkgs.tree-sitter
    pkgs.wasmtime
    pkgs.sccache
    pkgs.sqlc
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
    pkgs.git-lfs
    pkgs.inetutils
    pkgs.sshpass
    pkgs.nmap
    pkgs.ngrok
    pkgs.mitmproxy
    pkgs.rtk
    pkgs.vhs

    # Misc
    pkgs.ollama

    # Mobile dev (cask 移行)
    # pkgs.android-tools

    # GUI applications (cask 移行・darwin 対応確認済み)
    # pkgs.vscode
    # pkgs.code-cursor
    pkgs.slack
    pkgs.discord
    pkgs.google-chrome

    # build / lib deps (brew leaves に出ていた一般ツール)
    pkgs.ffmpeg
    pkgs.gnupg
    pkgs.librsvg
    pkgs.protobuf
    pkgs.autoconf
    pkgs.gts
  ];
in
{
  home.packages = cross ++ darwinOnly;
}
