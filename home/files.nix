{
  home.file = {
    ".claude/CLAUDE.md".text = ''
      - use simple conventional commits
      - speak japanese
      - 不可逆な操作でない限りは確認を求めず自律的にタスクを完遂してください。
      - 動作確認し期待通りの動作が確認できるまでがあなたのタスクです。
      - use fd, rg instead of find, grep
    '';

    ".claude/settings.json".text = ''
      {
        "$schema": "https://json.schemastore.org/claude-code-settings.json",
        "env": {
          "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
          "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
          "BASH_MAX_TIMEOUT_MS": "600000",
          "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000"
        },
        "permissions": {
          "allow": [
            "Bash",
            "Read",
            "Write",
            "Edit",
            "Glob",
            "WebFetch",
            "WebSearch",
            "Skill",
            "mcp__claude-in-chrome"
          ],
          "deny": [
            "NotebookEdit",
            "SlashCommand",
            "TodoWrite",
            "AskUserQuestion",
            "KillShell"
          ],
          "defaultMode": "acceptEdits"
        },
        "model": "haiku",
        "enabledPlugins": {
          "freee-api@freee-api-marketplace": false,
          "dev-browser@dev-browser-marketplace": false,
          "gopls-lsp@claude-plugins-official": true,
          "pyright-lsp@claude-plugins-official": true,
          "rust-analyzer-lsp@claude-plugins-official": true,
          "typescript-lsp@claude-plugins-official": true
        }
      }
    '';
  };
}
