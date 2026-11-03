# Agent Primer — `~/dotfiles`

Nix flake + nix-darwin + home-manager で aarch64-darwin の環境を宣言管理する。nix-darwin がマシン層、home-manager がユーザー層。

## どこに書くか

| やりたいこと | 置き場所 |
| --- | --- |
| `pkgs.<name>` だけで足りる package | `lib/package-registry.nix` に `mkEntry { pkg; purpose; reason; }` |
| 設定が要る program | `modules/programs/<name>.nix` を作り `home.nix` に import |
| システム層 (nix.conf, firewall, sudo, signed pkg) | `modules/darwin/*.nix` |
| upstream binary の CLI | `modules/programs/aqua/` の local registry + checksum |
| nixpkgs cache に無い GUI | 上流署名済み installer。root installer は `modules/darwin/native-apps/` |
| AI agent 共有 system prompt | `modules/programs/harness/AGENTS.md` が single source。live の `settings.json` / `opencode.json` は repo 管理しない |
| repo が使う secret | 正史は `~/.config/secrets/env.age`。repo の `.envrc` に `use secrets <KEY>` を書いて direnv で局所ロードする (`docs/operations.md` §2.6) |
| 運用手順 | 索引 `docs/playbooks.md`、本文 `docs/operations.md` / `docs/launchd.md` |
| 設計 / ADR | `docs/ideation/`, `docs/solutions/` |

## コマンド

| コマンド | 効果 |
| --- | --- |
| `nix run .#switch` | システム更新の適用。sudo で darwin-rebuild を実行する。ソフトウェア変更では使わない。 |
| `nix run .#homeConfigurations.hikae.activationPackage` | ソフトウェア層 (home-manager) の適用。sudo も OS 層の build も走らない。 |
| `nix fmt` / `nix run .#lint` | 整形 / deadnix + shellcheck |
| `nix flake check` | formatter + eval + guards |
| `nix run .#update` | 全 inputs を bump + eval gate |
| `nix run .#audit` / `.#xdg-audit` / `.#launchd-audit` | ledger 集計 / XDG drift / launchd drift |

タスク完了 = commit + push + 必要な適用 + 反映先の確認。

- 適用の要否は変更内容と実機の状態で判断する。変更ファイルの場所だけで OS 適用を決めない。
- OS 設定・サービスなどに未反映の変更がある場合だけ darwin-rebuild を実行する。OS 適用を伴う switch は sandbox 外で実行する。
- ユーザー層だけの反映には Home Manager の activationPackage を使い、OS 全体を適用しない。
- root installer の追加・変更は darwin-rebuild、Aqua だけなら Home Manager を適用する。
- docs / AGENTS.md / CI / tests だけの変更では switch しない。
- 適用は `~/dotfiles` の main からだけ行う。worktree や並行 agent から activationPackage / switch を実行しない。同時に走った activation は互いの generation を上書きし、host の状態が最後に走った branch で決まる。

## 規約

- declarative 優先。シェルから `git config --global` 等で永続変更しない。
- `home.packages` を直接書かず ledger 経由にする。purpose は `build/edit/ops/comm/observe/play/util`。
- ローカル source build 禁止。`cache.nixos.org` から output が取れる pkg だけを Nix registry に入れ、無い CLI は checksum 必須の Aqua、GUI は hash と Team ID を検証する上流署名済み installer へ逃がす。`overrideAttrs` でハッシュを変質させるパッチも禁止。
- git transport は HTTPS only。認証は `ghtkn git-credential` (GitHub App `ghtkn-hikae` の 8h user access token)。`gh` も ghtkn 経由の wrapper。再認証は `ghauth` を端末で実行する。
- secret は `~/.config/secrets/env.age` に置き、`.envrc` の `use secrets <KEY>` で必要な repo にだけ渡す。シェル起動時の全キー export、commit、`home.file` へのハードコードはしない。
- `flake.lock` は週次 workflow が更新する。手動で書き換えない。
- CI を緑にしてから merge。

## コメント

既定は書かない。書くなら WHY のみ、1 行、周辺コードと同じ言語。セクション見出し・バナー・「旧 X」「PR #N」等の時系列メタは書かない。

<!-- agentops:dreaming:start -->
# Project memory (managed by agentops dreaming — do not edit between markers)

## skills-install-convention ([[skills-install-convention]])
How to install agent skills on this machine — npx skills CLI, ~/.agents/skills shared dir, symlinks for claude-code and codex
<!-- agentops:dreaming:end -->
