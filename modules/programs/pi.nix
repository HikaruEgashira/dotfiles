{ pkgs, lib, ... }:

(import ../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Pi" [
  {
    rel = ".pi/agent/APPEND_SYSTEM.md";
    source = ./claude/CLAUDE.md;
  }
]
