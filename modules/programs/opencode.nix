_:
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
}
