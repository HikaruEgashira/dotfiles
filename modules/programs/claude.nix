{ pkgs, lib, ... }:

(import ../../lib/hm-managed-files.nix { inherit pkgs lib; }).files "Claude" [
  {
    rel = ".claude/CLAUDE.md";
    source = ./claude/CLAUDE.md;
  }
  {
    rel = ".claude/bin/claude-caffeinate.sh";
    source = ./claude/bin/claude-caffeinate.sh;
    executable = true;
  }
]
