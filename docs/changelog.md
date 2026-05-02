# Changelog — Survivor → PR Mapping

過去の ideation で立てた 7 Survivor + 派生作業の着地一覧 (ideation 自体は repo 外で保持)。各 Survivor は 1 PR で完結とは限らず、phase 単位で複数 PR に分割している。

## Survivor 着地マトリクス

| #   | Survivor                            | 状態            | 主 PR                                                                                                                                                                                                                                                                                             | 残作業 (user-action)                                                                                                                        |
| --- | ----------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 計測駆動 Reproducibility パイプ     | ✅ 全効力       | [#12](https://github.com/HikaruEgashira/dotfiles/pull/12)                                                                                                                                                                                                                                         | trusted-users 設定済 (本セッション)                                                                                                         |
| 2   | Package Ledger                      | ✅ Phase 1+2    | [#13](https://github.com/HikaruEgashira/dotfiles/pull/13) [#14](https://github.com/HikaruEgashira/dotfiles/pull/14) [#19](https://github.com/HikaruEgashira/dotfiles/pull/19) [#20](https://github.com/HikaruEgashira/dotfiles/pull/20) [#24](https://github.com/HikaruEgashira/dotfiles/pull/24) | launchd weekly sweep + `expires` enforcement                                                                                                |
| 3   | Secret-file Eradication             | △ Part 1        | [#23](https://github.com/HikaruEgashira/dotfiles/pull/23)                                                                                                                                                                                                                                         | AWS IAM Identity Center 移行 (laptop に AKIA を残さない)。SSH 認証は `~/.ssh/id_ed25519` + macOS Keychain で運用 (1Password agent は不採用) |
| 4   | Pre-commit Flake Module / lint 集約 | ✅ Phase 1+2    | [#16](https://github.com/HikaruEgashira/dotfiles/pull/16) [#17](https://github.com/HikaruEgashira/dotfiles/pull/17) [#21](https://github.com/HikaruEgashira/dotfiles/pull/21)                                                                                                                     | treefmt polyglot 拡張 (該当言語ファイル発生待ち)、AGENTS.md auto-gen                                                                        |
| 5   | GitOps + multi-host matrix          | △ 足場          | [#22](https://github.com/HikaruEgashira/dotfiles/pull/22)                                                                                                                                                                                                                                         | 実 host 追加と `repository_dispatch` 経由 event-driven 化                                                                                   |
| 6   | MEL (Minimum Equipment List)        | ✅ MVP          | [#18](https://github.com/HikaruEgashira/dotfiles/pull/18)                                                                                                                                                                                                                                         | USB DR snapshot 四半期 cron (外部メディア要件)                                                                                              |
| 7   | Gitleaks 一重化                     | ✅ pre-existing | [#11](https://github.com/HikaruEgashira/dotfiles/pull/11)                                                                                                                                                                                                                                         | —                                                                                                                                           |

## 派生 PR

| PR                                                        | 役割                                                                                                            |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [#15](https://github.com/HikaruEgashira/dotfiles/pull/15) | `gh auth setup-git` の brew-path hardcode を `home.activation` で declarative 化 + 旧 `~/.gitconfig` 設定パージ |
| [#14](https://github.com/HikaruEgashira/dotfiles/pull/14) | `coreutils` には `column` が無い → `gawk` printf に置換 (#13 hot-fix)                                           |
| [#24](https://github.com/HikaruEgashira/dotfiles/pull/24) | `ms-vscode.cpptools` が darwin で removed list 入り → 拡張リストから除外 (#19 hot-fix)                          |

## 設計判断のサマリ

ideation doc に書いていない、実装中に確定した design decisions:

| 判断                                                                                                                                                                | 根拠                                                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Package Ledger は `lib/package-registry.nix` を single source of truth に切り出し、`modules/packages.nix` (consumer) と `apps.<system>.audit` (consumer) が共有する | metadata の二重管理を避けるため。`programs.X.package` は ledger 対象外 (module 単位で audit)                                                  |
| Lint app は treefmt と分離                                                                                                                                          | treefmt = 整形 (副作用あり)、lint = 検証 (read-only)。同一 entrypoint だと CI gate の意味付けが曖昧になる                                     |
| `apps.<system>` 経由で audit / lint を提供                                                                                                                          | `nix run .#X` という統一 UX。手元・CI 同一コードで動かせる                                                                                    |
| Multi-host は `forSystem` を `forHost` に置換 + `hosts` attrset を表に                                                                                              | 表 1 行追加 + `hosts/<host>/default.nix` 1 ファイルで host 増設可能。base (`home.nix`) を分岐させない                                         |
| MEL は `linkFarmFromDrvs` で 1 derivation 化                                                                                                                        | `symlinkJoin` だと衝突するファイル (zsh/gnupg 等) で fail する。linkFarmFromDrvs は名前衝突を pname で回避                                    |
| Determinism gate は eval 段階のみ                                                                                                                                   | build determinism (output hash 一致) は CI 完全 build を要する。現状 CI は eval-only なので eval 段階の drvPath 安定性 (impurity 検出) に絞る |
| credential.helper 修正は `home.activation.purgeStaleGhCredentialHelper` で旧設定を unset                                                                            | `~/.gitconfig` (legacy) は HM-managed `~/.config/git/config` を override するため、旧設定を残したままだと新設定が無効化される                 |
| statix の `manual_inherit_from` (W04) を一律 disable                                                                                                                | `writeShellScriptBin` 内 indented-string の `${pkgs.X}` を assignment と誤検出するため。`statix.toml` で project-wide に抑制                  |

## 設計判断のうち再考余地があるもの

将来見直すかもしれない選択 (今は確定だが anti-pattern 化したら revisit):

- **VS Code 拡張は `vscode-marketplace` のみ**: `open-vsx` を fallback に使う設計はしていない。MS proprietary な拡張 (`cpptools` 等) を諦めたら open-vsx 切替を検討。
- **MEL は固定 10 packages**: ADR を要求する閉じた集合だが、`vim` / `nvim` を加えるか議論余地あり。
- **`hosts` 表に system を持たせている**: 全 host が `aarch64-darwin` なら冗長。逆に Linux host を増やすなら今の構造のまま使える。
- **lint app と CI の duplication**: `nix run .#lint` と `.github/workflows/ci.yml` の `Run linters` ステップは同じことをする。CI 側を `nix run .#lint` 1 行に絞っているが、CI 専用検査 (例: PR 件数しきい値) を増やすなら別 entrypoint が要る。

## 今後の Survivor 継続条件

| Survivor                     | 次のアクションが取れる条件                                   |
| ---------------------------- | ------------------------------------------------------------ |
| #2 phase 3 (launchd sweep)   | `expires` を実エントリに振る運用合意ができたら               |
| #3 完全 (AKIA 撤去)          | AWS account 側で IAM Identity Center が設定されたら          |
| #4 (treefmt polyglot)        | Python / TS / Go / Lua いずれかのファイルがリポに発生したら  |
| #4 (AGENTS.md auto-gen)      | module 数が今後 2 倍以上に増え、手書きが追従できなくなったら |
| #5 (event-driven multi-host) | 2 台目 host が物理的に増えたら                               |
| #6 (USB DR snapshot)         | 外部メディア (USB or Time Machine drive) の所在が決まったら  |
