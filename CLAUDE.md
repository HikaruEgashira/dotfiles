# dotfiles

このファイルは AGENTS.md への薄いブリッジ。レイアウト・規約・実行可能エントリポイント・避けるべき変更は `AGENTS.md` を参照。

## 適用

設定変更は適用までがタスク完了の定義。commit/push に加えて必ず以下を実行し、反映先ファイルを確認する。

```bash
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

注意: Claude Code の `settings.json` は repo で管理しない。実効設定は live ファイル `~/.claude/settings.json`（Claude Code が起動毎に直接書き換える通常ファイル）が source of truth。settings 変更は live ファイルを直接編集する。repo の `modules/programs/claude.nix` が配置するのは CLAUDE.md / hooks / statusline 等のみ。`modules/programs/claude/CLAUDE.md` は全エージェント共通の single source で、`codex.nix` が `~/.codex/AGENTS.md` に、`pi.nix` が `~/.pi/agent/APPEND_SYSTEM.md` に配置し、`opencode.nix` が ponytail と連結して `~/.config/opencode/AGENTS.md` に配置する。`AGENTS.md` 参照。
