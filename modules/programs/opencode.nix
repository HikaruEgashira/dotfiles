{ lib, ... }:
let
  # opencode loads only the first existing global instruction file, so merge ponytail into it.
  content = builtins.readFile ./claude/CLAUDE.md + "\n" + builtins.readFile ./opencode/ponytail.md;
in
{
  home.file.".config/opencode/AGENTS.md" = {
    text = content;
    force = true;
  };

  # opencode は自己更新する binary なので dotfiles からは起動前 preflight だけを差し込む
  programs.zsh.initContent = lib.mkAfter (builtins.readFile ./opencode/preflight.sh);
}
