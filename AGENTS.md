# Agent Primer — `~/dotfiles`

Nix flake + nix-darwin + home-manager で aarch64-darwin の環境を宣言管理する。nix-darwin がマシン層、home-manager がユーザー層。

## どこに書くか

| やりたいこと | 置き場所 |
| --- | --- |
| `pkgs.<name>` だけで足りる package | `lib/package-registry.nix` に `mkEntry { pkg; purpose; reason; }` |
| 設定が要る program | `modules/programs/<name>.nix` を作り `home.nix` に import |
| システム層 (nix.conf, firewall, sudo, Homebrew) | `modules/darwin/*.nix` |
| nixpkgs に無い GUI / kext | `modules/darwin/homebrew.nix` (理由と nix 化のトリガーを行コメントで) |
| AI agent 共有 system prompt | `modules/programs/claude/CLAUDE.md` が single source。live の `settings.json` / `opencode.json` は repo 管理しない |
| 運用手順 | 索引 `docs/playbooks.md`、本文 `docs/operations.md` / `docs/launchd.md` |
| 設計 / ADR | `docs/ideation/`, `docs/solutions/` |

## コマンド

| コマンド | 効果 |
| --- | --- |
| `nix run .#switch` | ユーザー層を root なしで適用。OS 層 (`modules/darwin`, `hosts`) に差分がある時だけ sudo で darwin-rebuild が走る |
| `nix fmt` / `nix run .#lint` | 整形 / deadnix + shellcheck |
| `nix flake check` | formatter + eval + guards |
| `nix run .#update` | 全 inputs を bump + eval gate |
| `nix run .#audit` / `.#xdg-audit` / `.#launchd-audit` | ledger 集計 / XDG drift / launchd drift |

タスク完了 = commit + push + `nix run .#switch` + 反映先の確認。OS 層を変えた時の switch は sandbox 外で実行する。

## 規約

- declarative 優先。シェルから `git config --global` 等で永続変更しない。
- `home.packages` を直接書かず ledger 経由にする。purpose は `build/edit/ops/comm/observe/play/util`。
- ローカル source build 禁止。`cache.nixos.org` から output が取れる pkg だけを registry に入れ、無いものは Homebrew か上流の署名済みインストーラへ逃がす。`overrideAttrs` でハッシュを変質させるパッチも禁止。
- git transport は HTTPS only。認証は `gh auth git-credential`。
- 新規 secret は `direnv` でセッション局所に閉じ、commit も `home.file` へのハードコードもしない。
- `flake.lock` は週次 workflow が更新する。手動で書き換えない。
- CI を緑にしてから merge。

## コメント

既定は書かない。書くなら WHY のみ、1 行、周辺コードと同じ言語。セクション見出し・バナー・「旧 X」「PR #N」等の時系列メタは書かない。

<!-- agentops:dreaming:start -->
# Project memory (managed by agentops dreaming — do not edit between markers)

## skills-install-convention ([[skills-install-convention]])
How to install agent skills on this machine — npx skills CLI, ~/.agents/skills shared dir, symlinks for claude-code and codex
<!-- agentops:dreaming:end -->
