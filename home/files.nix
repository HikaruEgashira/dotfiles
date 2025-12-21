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
        "model": "opus"
      }
    '';
  };
}
