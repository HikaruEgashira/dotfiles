# dotfiles

このファイルは AGENTS.md への薄いブリッジ。レイアウト・規約・実行可能エントリポイント・避けるべき変更は `AGENTS.md` を参照。

## 適用

設定変更は適用までがタスク完了の定義。commit/push に加えて必ず以下を実行し、反映先ファイルを確認する。

```bash
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

注意: `modules/programs/claude/settings.json` は `modules/programs/claude.nix` の `managed` リストに含まれず home-manager で配置されない（orphan）。Claude Code の実効設定は live ファイル `~/.claude/settings.json`（Claude Code が直接書き換える通常ファイル）。settings 変更を反映するには live ファイルを直接編集する必要がある。`AGENTS.md` 参照。
