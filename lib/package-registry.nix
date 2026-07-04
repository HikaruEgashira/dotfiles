{
  pkgs,
  lib,
}:

let
  ledger = import ./ledger.nix { inherit lib; };
  inherit (ledger) mkEntry;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  cross = [
    (mkEntry {
      pkg = pkgs.cachix;
      purpose = "build";
      reason = "binary cache CLI";
    })
    (mkEntry {
      pkg = pkgs.pinentry-curses;
      purpose = "ops";
      reason = "GnuPG passphrase prompt";
    })
    (mkEntry {
      pkg = pkgs.lato;
      purpose = "edit";
      reason = "fallback font for terminals";
    })
    (mkEntry {
      pkg = pkgs.devenv;
      purpose = "build";
      reason = "dev shells per project";
    })

    (mkEntry {
      pkg = pkgs.gh;
      purpose = "edit";
      reason = "GitHub CLI / PR ops";
    })
    (mkEntry {
      pkg = pkgs.ripgrep;
      purpose = "util";
      reason = "primary code search";
    })
    (mkEntry {
      pkg = pkgs.fd;
      purpose = "util";
      reason = "primary find replacement";
    })
    (mkEntry {
      pkg = pkgs.gitleaks;
      purpose = "ops";
      reason = "secret scanning hook";
    })
    (mkEntry {
      pkg = pkgs.pinact;
      purpose = "ops";
      reason = "GitHub Actions SHA pin";
    })

    (mkEntry {
      pkg = pkgs.awscli2;
      purpose = "ops";
      reason = "AWS CLI";
    })
    (mkEntry {
      pkg = pkgs.google-cloud-sdk;
      purpose = "ops";
      reason = "Google Cloud CLI";
    })
    (mkEntry {
      pkg = pkgs.cloudflared;
      purpose = "ops";
      reason = "Cloudflare Tunnel client";
    })
    (mkEntry {
      pkg = pkgs.flyctl;
      purpose = "ops";
      reason = "Fly.io CLI";
    })
    (mkEntry {
      pkg = pkgs.trivy;
      purpose = "ops";
      reason = "container/IaC vulnerability scan";
    })
    (mkEntry {
      pkg = pkgs.trufflehog;
      purpose = "ops";
      reason = "secret scanner (audit-only)";
    })
    (mkEntry {
      pkg = pkgs.sops;
      purpose = "ops";
      reason = "encrypted config files";
    })

    (mkEntry {
      pkg = pkgs.docker-buildx;
      purpose = "build";
      reason = "multi-arch container build";
    })
    (mkEntry {
      pkg = pkgs.podman;
      purpose = "build";
      reason = "rootless container runtime";
    })
    (mkEntry {
      pkg = pkgs.qemu;
      purpose = "build";
      reason = "cross-arch emulation backend";
    })
    (mkEntry {
      pkg = pkgs.lima;
      purpose = "build";
      reason = "macOS Linux VM";
    })
    (mkEntry {
      pkg = pkgs.devcontainer;
      purpose = "build";
      reason = "devcontainer CLI";
    })

    (mkEntry {
      pkg = pkgs.cmake;
      purpose = "build";
      reason = "C/C++ build system";
    })
    (mkEntry {
      pkg = pkgs.automake;
      purpose = "build";
      reason = "autotools build";
    })
    (mkEntry {
      pkg = pkgs.pkg-config;
      purpose = "build";
      reason = "library probe";
    })
    (mkEntry {
      pkg = pkgs.golangci-lint;
      purpose = "build";
      reason = "Go meta-linter";
    })
    (mkEntry {
      pkg = pkgs.nixfmt;
      purpose = "build";
      reason = "Nix formatter matching `nix fmt`";
    })
    (mkEntry {
      pkg = pkgs.ast-grep;
      purpose = "build";
      reason = "syntactic codemod";
    })
    (mkEntry {
      pkg = pkgs.tree-sitter;
      purpose = "build";
      reason = "parser generator";
    })
    (mkEntry {
      pkg = pkgs.wasmtime;
      purpose = "build";
      reason = "WASM runtime";
    })
    (mkEntry {
      pkg = pkgs.sccache;
      purpose = "build";
      reason = "rust compile cache";
    })
    (mkEntry {
      pkg = pkgs.sqlc;
      purpose = "build";
      reason = "SQL -> Go codegen";
    })
    (mkEntry {
      pkg = pkgs.dotenvx;
      purpose = "ops";
      reason = "encrypted .env loader";
    })

    (mkEntry {
      pkg = pkgs.duckdb;
      purpose = "ops";
      reason = "embedded analytics DB";
    })
    (mkEntry {
      pkg = pkgs.postgresql_14;
      purpose = "ops";
      reason = "local Postgres for projects";
    })
    (mkEntry {
      pkg = pkgs.redis;
      purpose = "ops";
      reason = "local Redis for projects";
    })

    (mkEntry {
      pkg = pkgs.coreutils;
      purpose = "util";
      reason = "GNU coreutils on Darwin";
    })
    (mkEntry {
      pkg = pkgs.tree;
      purpose = "util";
      reason = "directory listing";
    })
    (mkEntry {
      pkg = pkgs.htop;
      purpose = "observe";
      reason = "process monitor";
    })
    (mkEntry {
      pkg = pkgs.jq;
      purpose = "util";
      reason = "JSON processor";
    })
    (mkEntry {
      pkg = pkgs.jj;
      purpose = "edit";
      reason = "Jujutsu VCS";
    })
    (mkEntry {
      pkg = pkgs.just;
      purpose = "build";
      reason = "task runner";
    })
    (mkEntry {
      pkg = pkgs.nushell;
      purpose = "util";
      reason = "structured-data shell";
    })
    (mkEntry {
      pkg = pkgs.pueue;
      purpose = "ops";
      reason = "background task queue";
    })
    (mkEntry {
      pkg = pkgs.rclone;
      purpose = "ops";
      reason = "cloud storage sync";
    })
    (mkEntry {
      pkg = pkgs.git-lfs;
      purpose = "edit";
      reason = "Git LFS";
    })
    (mkEntry {
      pkg = pkgs.inetutils;
      purpose = "util";
      reason = "telnet/ftp on Darwin";
    })
    (mkEntry {
      pkg = pkgs.sshpass;
      purpose = "ops";
      reason = "non-interactive SSH";
    })
    (mkEntry {
      pkg = pkgs.nmap;
      purpose = "ops";
      reason = "network probe";
    })
    (mkEntry {
      pkg = pkgs.mitmproxy;
      purpose = "observe";
      reason = "HTTPS interception debug";
    })
    (mkEntry {
      pkg = pkgs.rtk;
      purpose = "play";
      reason = "LLM token reduction proxy";
    })
    (mkEntry {
      pkg = pkgs.vhs;
      purpose = "play";
      reason = "terminal recording";
    })

    (mkEntry {
      pkg = pkgs.herdr;
      purpose = "edit";
      source = "flake:ogulcancelik/herdr";
      reason = "AI coding agent multiplexer (TUI)";
    })
    (mkEntry {
      pkg = pkgs.ollama;
      purpose = "play";
      reason = "local LLM serving";
    })
    (mkEntry {
      pkg = pkgs.python3Packages.huggingface-hub;
      purpose = "play";
      reason = "Hugging Face Hub CLI (hf / huggingface-cli)";
    })

    (mkEntry {
      pkg = pkgs.slack;
      purpose = "comm";
      reason = "team chat";
    })
    (mkEntry {
      pkg = pkgs.discord;
      purpose = "comm";
      reason = "community chat";
    })
    (mkEntry {
      pkg = pkgs.google-chrome;
      purpose = "comm";
      reason = "browser fallback";
    })

    (mkEntry {
      pkg = pkgs.ffmpeg;
      purpose = "util";
      reason = "video/audio encoder";
    })
    (mkEntry {
      pkg = pkgs.gnupg;
      purpose = "ops";
      reason = "GnuPG";
    })
    (mkEntry {
      pkg = pkgs.librsvg;
      purpose = "build";
      reason = "SVG rasterizer for build deps";
    })
    (mkEntry {
      pkg = pkgs.protobuf;
      purpose = "build";
      reason = "protoc";
    })
    (mkEntry {
      pkg = pkgs.autoconf;
      purpose = "build";
      reason = "autotools";
    })
    (mkEntry {
      pkg = pkgs.gts;
      purpose = "build";
      reason = "GNU triangulated surface lib";
    })
  ];

  # CI evaluates on x86_64-linux; entries here must not leak into `cross`
  darwinOnly = lib.optionals isDarwin [
    (mkEntry {
      pkg = pkgs.cocoapods;
      purpose = "build";
      reason = "iOS native dep manager";
    })
    (mkEntry {
      pkg = pkgs.mas;
      purpose = "ops";
      reason = "Mac App Store CLI";
    })
    (mkEntry {
      pkg = pkgs.duti;
      purpose = "ops";
      reason = "default app association";
    })
    (mkEntry {
      pkg = pkgs.terminal-notifier;
      purpose = "util";
      reason = "macOS notification trigger";
    })
    (mkEntry {
      pkg = pkgs.iproute2mac;
      purpose = "ops";
      reason = "ip(8) on Darwin";
    })
    (mkEntry {
      pkg = pkgs.raycast;
      purpose = "edit";
      reason = "launcher / extension host";
    })
  ];
in
{
  inherit cross darwinOnly;
  all = cross ++ darwinOnly;
}
