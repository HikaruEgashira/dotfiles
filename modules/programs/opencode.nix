{ lib, pkgs, ... }:
let
  # opencode loads only the first existing global instruction file, so merge ponytail into it.
  content =
    builtins.readFile ./claude/CLAUDE.md + "\n" + builtins.readFile ../../opencode/ponytail/AGENTS.md;
in
{
  home.file.".config/opencode/AGENTS.md" = {
    text = content;
    force = true;
  };

  home.activation.preNixOpencodeBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    file="$HOME/.config/opencode/AGENTS.md"
    if [ -e "$file" ] && [ ! -L "$file" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$file" "$file.pre-nix"
    fi
  '';
}
