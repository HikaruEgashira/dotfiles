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

| やりたいこと                       | 置き場所                                                               |
| ---------------------------------- | ---------------------------------------------------------------------- |
| `pkgs.<name>` だけで足りる package | `lib/package-registry.nix` (`mkEntry { pkg; purpose; reason; }`)       |
| 設定が要る program                 | `modules/programs/<name>.nix` を新規作成、`home.nix` に `imports` 追加 |
| GUI / kext / nixpkgs に無いもの    | `Brewfile` (理由をコメントで残す)                                      |
| CLI 補助・チートシート             | `modules/settings/<topic>.{sh,md}`                                     |
| ideation / 設計                    | `docs/ideation/YYYY-MM-DD-<topic>-ideation.md`                         |
| ADR / 解決策                       | `docs/solutions/<problem-type>/<id>.md` (未整備)                       |

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
- **CI ゲート 4 段**: treefmt formatter / home-manager eval / determinism gate / lint (deadnix + shellcheck)。緑にしてから merge。
- **シークレット**: `~/.aws/credentials` の long-term AKIA 撤去と `1Password CLI + Secure Enclave` への移行が継続中 (Survivor #3)。新規秘密は `op run --` か `direnv` 経由でセッション局所に閉じ、commit しない。SSH 認証は `modules/programs/ssh.nix` の `dotfiles.onePasswordSshAgent.enable` を立てれば 1Password agent 経由になる (1Password app と Secure Enclave key の事前用意が前提なので既定 OFF)。

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

- ideation: `docs/ideation/2026-05-02-secure-fast-lean-dotfiles-ideation.md`
- README (人間向け): `README.md`
- AWS architecture (ADR-0008): `modules/programs/aws.nix` 冒頭コメント
