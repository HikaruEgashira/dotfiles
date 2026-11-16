# managed settings はユーザーの settings.json より優先され、Claude Code やツールの書き込みで消えない
{ lib, pkgs, ... }:

let
  managedSettings = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON {
      env.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
      syncClaudeAiSkills = false;
    }
  );
  dir = "/Library/Application Support/ClaudeCode";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    install -d -m 755 -o root -g wheel "${dir}"
    install -m 644 -o root -g wheel ${managedSettings} "${dir}/managed-settings.json"
  '';
}
