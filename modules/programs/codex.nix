{ pkgs, lib, ... }:

(import ../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Codex" [
  {
    rel = ".codex/AGENTS.md";
    source = ./claude/CLAUDE.md;
  }
]
