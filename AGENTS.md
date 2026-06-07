# Agent Primer — `~/dotfiles`

このリポジトリは Nix flake + home-manager で aarch64-darwin 上の開発環境を再現可能に管理する。AI エージェント (Claude Code 等) は本ドキュメントを起点に、どこに何を書くかを判断する。

## レイアウト 5 行

```
flake.nix              substituter / formatter / checks / apps を宣言
home.nix               モジュールを束ねる
modules/programs/*.nix 設定が要るプログラム (zsh, git, tmux, ghostty, etc.)
modules/packages.nix   設定不要な home.packages を ledger 経由で宣言
lib/{ledger,package-registry}.nix  パッケージ ledger のデータ層
```

## 何をどこに書くか

| やりたいこと                       | 置き場所                                                                                                                                 |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `pkgs.<name>` だけで足りる package | `lib/package-registry.nix` (`mkEntry { pkg; purpose; reason; }`)                                                                         |
| 設定が要る program                 | `modules/programs/<name>.nix` を新規作成、`home.nix` に `imports` 追加                                                                   |
| GUI / kext / nixpkgs に無いもの    | `Brewfile` (理由をコメントで残す)                                                                                                        |
| CLI 補助・チートシート             | `modules/settings/<topic>.{sh,md}`                                                                                                       |
| Claude Code のユーザー設定         | `modules/programs/claude/<file>` (CLAUDE.md / hooks / statusline 等); `settings.json` は repo 管理せず live `~/.claude/settings.json` が source of truth; MCP は `claude mcp add --scope user` で `~/.claude.json` に登録 |
| ideation / 設計                    | `docs/ideation/YYYY-MM-DD-<topic>-ideation.md`                                                                                           |
| ADR / 解決策                       | `docs/solutions/<problem-type>/<id>.md` (未整備)                                                                                         |

## 実行可能エントリポイント

| コマンド                                                        | 効果                                              |
| --------------------------------------------------------------- | ------------------------------------------------- |
| `nix run ~/dotfiles#homeConfigurations.hikae.activationPackage` | activation を実行 (本番適用)                      |
| `nix flake update ~/dotfiles`                                   | inputs を bump (週次 GitHub Actions が PR を出す) |
| `nix fmt`                                                       | treefmt で nix / md / yaml / sh / json を整形     |
| `nix flake check`                                               | formatter + home-manager build + apps eval        |
| `nix run .#audit`                                               | Package Ledger の purpose 別集計と全エントリ表    |
| `nix run .#lint`                                                | deadnix + shellcheck (CI でも実行)                |
| `brew bundle --file=~/dotfiles/Brewfile`                        | nix で扱えない GUI / kext / cask の同期           |

## 規約 (Secure By Design)

- **declarative 優先**: シェルから `git config --global` 等で永続変更しない。`programs.git.settings` に書く。`~/.gitconfig` の設定は HM-管理の `~/.config/git/config` を上書きするため、レガシーが残っていれば `home.activation` で `--unset-all` する。
- **ledger 経由**: `home.packages` を直接書かない。`lib/package-registry.nix` に `mkEntry` で宣言し、purpose (`build`/`edit`/`ops`/`comm`/`observe`/`play`/`util` の 7 値) と `reason` を記す。
- **逃げ場の明文化**: `Brewfile` に書く時は理由を行コメントで残し、nix 化のトリガーが何かを書く (例: codex CLI の nix 化が ripgrep の brew 削除のトリガー)。
- **ローカルソースビルド禁止**: 手元での source build (= 上流リポのコードを `buildPhase` で実行する derivation) はサプライチェーンリスク (依存ツリー全域でのコンパイル時 RCE 機会) が高いため、`lib/package-registry.nix` に追加するのは `cache.nixos.org` から output がそのまま取れる pkg のみ。`overrideAttrs` で version / src / 環境変数 / `doCheck` を変えて結果ハッシュを変質させるパッチも (cache を逸脱して再コンパイルを誘発するので) 禁止。nixpkgs binary cache が無いものは `Brewfile` (署名付きの bottle / cask) か、上流公式の署名済みインストーラ (例: `curl https://mise.run \| sh`) に逃がす。検証: `nix path-info --derivation` でその pkg の output ハッシュを取り `https://cache.nixos.org/$HASH.narinfo` に HEAD して 200 を確認する。ハッシュ固定の fetchurl / fetchzip / VSIX unpack 系 (`buildPhase` 空 + `unpack-vsix-setup-hook` 等の copy-only hook) と HM の config-derived ラッパー (`hm_*`, `home-manager-*`, `*-config`, `home-manager-fonts`) は対象外 — 上流コードを動かさない。
- **CI ゲート 4 段**: treefmt formatter / home-manager eval / determinism gate / lint (deadnix + shellcheck)。緑にしてから merge。
- **シークレット**: `~/.aws/credentials` の long-term AKIA 撤去 (IAM Identity Center 移行) は継続中。新規秘密は `direnv` (`.envrc`) 経由でセッション局所に閉じ、commit しない。
- **git transport は HTTPS only**: `programs.git.settings.url` の `insteadOf` で `git@github.com:` / `ssh://git@github.com/` を `https://github.com/` に強制 rewrite し、認証は `gh auth git-credential` (HTTPS + token) に一本化する。SSH 鍵による git auth は使わない (commit signing 用の SSH 鍵は別軸で維持)。

## インラインコメントの書き方

コードは自己ドキュメントが原則。コメントは **書かないのが既定**で、書く時は以下に従う。

- **書く時は WHY のみ**: code 自体が WHAT を語る (well-named identifier / explicit settings)。コメントは「なぜこの選択をしたか」「なぜここで通常と違うことをしているか」だけ。同じことを言い換えるコメントは消す。
- **1 行が上限**: 段落・複数行のブロックヘッダ・装飾的なファイルバナー (`# ===== Section =====` 等) は禁止。複数事象を語りたくなったら `docs/` に書く。
- **rot するメタ参照を書かない**: 「Survivor #N」「PR #M」「ADR-XXXX」「次 PR で対応」等は repo 側 (`docs/changelog.md` 等) に集約する。コードに固有名を残さない。例外は外部の安定 ID (CVE / 上流 issue / 仕様番号) のみ。
- **目次的な区切りコメントを書かない**: `# rust`, `# path`, `# DB / data` のようなセクションラベルは ledger の `purpose` 等の構造化メタデータで代替する。grep / outline で十分追える場合は不要。
- **「廃止/移行/旧体制」を書かない**: 削除した時点で消す。git history が経緯の正史。「旧 X は ...」のような時系列メタは書き残さない。
- **書く時の言語は周辺コードに合わせる**: 1 ファイル内で日英混在させない (混ざっているなら片方に寄せる)。
- **Bash/zsh は `set -eu` を前提にできる場合は `command -v` 等のガードもコメント不要**: ガードがあること自体が意図を語る。

例:

```nix
# OK — non-obvious WHY in 1 line
direnv = prev.direnv.overrideAttrs (_: { doCheck = false; });  # test-zsh hangs on aarch64-darwin

# NG — restates WHAT
# direnv の test を無効化する
direnv = prev.direnv.overrideAttrs (_: { doCheck = false; });

# NG — rotting meta-ref
# Survivor #2 phase 2 で導入。詳細は docs/ideation/...
```

## 同期と多重マシン

- daily 09:00 launchd で `dotfiles-sync` が `main` 追従。clean tree のみ。
- weekly GitHub Actions が `flake.lock` を auto-merge PR で更新。
- 各 sync の結果は `~/.cache/dotfiles-sync/metrics.jsonl` に追記される (`outcome` / `wall_s` / `head_before` / `head_after`)。
- 2 台目以降の追加: `hosts/<host>/default.nix` を作成し、`flake.nix` の `hosts` attrset に 1 行追加するだけ。`home.nix` は universal な base としてそのまま、host 固有 override (proxy / 別 identity / screenlock など) は host モジュール側に書く。`extraSpecialArgs.host` が各モジュールから参照可能なので必要なら module 内で `if host == "hikae@work" then ... else ...` の分岐も書ける。

## エージェントが避けるべき変更

- `flake.lock` を手動で書き換える (週次 PR の責務)
- `~/.gitconfig` を直接編集 (`programs.git.settings` 経由)
- `Brewfile` に新規 `vscode "..."` 行を足す (`programs.vscode.extensions` への移行が方針)
- 本番秘密を `home.file` でハードコードする (declarative ≠ plaintext OK ではない)
- CI を skip するための `--no-warn-dirty` の濫用 (`dotfiles-sync` 内では意図的に使われている例外)

## 詳細リンク

- 「どう操作するか」: `docs/operations.md` (運用 cookbook、トラブルシュート、ロールバック、新マシン bootstrap)
- 「何ができたか」: `docs/changelog.md` (Survivor → PR マトリクス、設計判断のサマリ、再考余地、継続条件)
- README (人間向け): `README.md`
- AWS architecture (ADR-0008): `modules/programs/aws.nix` 冒頭コメント

<!-- agentops:dreaming:start -->
# Project memory (managed by agentops dreaming — do not edit between markers)
<!-- agentops:dreaming:end -->
