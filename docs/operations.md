# Operations Cookbook

`~/dotfiles` の運用レシピ集。「どう書くか」は `AGENTS.md`、「なぜそう設計したか」は `docs/ideation/` と各 PR description、「何ができたか」は `docs/changelog.md`。本ドキュメントは「どう操作するか」のみを扱う。

## 1. 日常運用

| やりたいこと  | コマンド                                                        | 備考                                                                 |
| ------------- | --------------------------------------------------------------- | -------------------------------------------------------------------- |
| 設定を反映    | `nix run ~/dotfiles#homeConfigurations.hikae.activationPackage` | 冪等。`--accept-flake-config` は trusted-users 設定後は不要          |
| ledger 棚卸し | `nix run ~/dotfiles#audit`                                      | purpose 別集計 + 全 entry 表 + expires 切れ件数                      |
| 静的検査      | `nix run ~/dotfiles#lint`                                       | statix + deadnix + shellcheck (CI と同一)                            |
| 整形          | `nix fmt ~/dotfiles`                                            | nixfmt + prettier + shfmt                                            |
| flake gate    | `nix flake check ~/dotfiles --accept-flake-config`              | formatter + eval + apps + checks                                     |
| inputs 更新   | `nix flake update ~/dotfiles`                                   | 週次 GitHub Actions が PR を auto-merge する。手動更新はめったに不要 |
| 同期実績      | `tail -n5 ~/.cache/dotfiles-sync/metrics.jsonl`                 | `outcome / wall_s / head_before / head_after`                        |

## 2. 何かを追加する

### 2.1 新しい `home.packages` を足す

1. `lib/package-registry.nix` の `cross` (or `darwinOnly`) に追加:
   ```nix
   (mkEntry { pkg = pkgs.<NAME>; purpose = "build"; reason = "<one line>"; })
   ```
2. `purpose` は `build` / `edit` / `ops` / `comm` / `observe` / `play` / `util` の 7 値固定。新カテゴリは `lib/ledger.nix` の `purposes` 修正と ADR 起票が要る。
3. `nix run .#audit` で出てくれば成功。

### 2.2 新しい program を足す (設定が必要なもの)

1. `modules/programs/<NAME>.nix` を作成。
2. `home.nix` の `imports` にパスを追加。
3. `nix flake check --accept-flake-config` で eval 通過を確認。

### 2.3 新しい VS Code 拡張を足す

1. `modules/programs/vscode.nix` の `extensionIds` に `"<publisher>.<name>"` を追加 (名前順)。
2. `nix flake check` で eval 通過を確認。`throw "vscode extension not found ..."` が出たら overlay にその拡張がない (新規すぎる / removed list) — `nix-vscode-extensions` の `removed.nix` を確認して anycode 等で代替するか Brewfile 一時退避。
3. `Brewfile` への `vscode "..."` 追加は CI で fail するので避ける。

### 2.4 新しい host (2 台目以降) を足す

1. `hosts/<HOST>/default.nix` を新規作成。host 固有の override (proxy / 別 identity / screenlock) を書く。
2. `flake.nix` の `hosts` attrset に 1 行追加:
   ```nix
   hosts = {
     hikae = { system = "aarch64-darwin"; };
     "<HOST>" = { system = "aarch64-darwin"; };
   };
   ```
3. 新 host で `nix run github:HikaruEgashira/dotfiles#homeConfigurations.<HOST>.activationPackage`。

### 2.5 nixpkgs に無い GUI / kext を足す

1. `Brewfile` に `cask "<NAME>"` で追加。
2. 直前のコメント行に nix 化できない理由を残す (例: `# nixpkgs broken`, `# kext required`)。
3. nix 化できるようになったら Brewfile から削除し `lib/package-registry.nix` に移す。

## 3. オプトイン機能を有効化する

### 3.1 sudo で Touch ID を使う

```bash
~/dotfiles/scripts/sudo-touchid.sh status
~/dotfiles/scripts/sudo-touchid.sh enable
```

無効化するとき:

```bash
~/dotfiles/scripts/sudo-touchid.sh disable
```

このスクリプトは `/etc/pam.d/sudo` を安全に更新し、`root:wheel` / `0644` を維持する。

### 3.2 cachix substituter を実効化 (Survivor #1)

1 度だけ:

```bash
echo 'extra-trusted-users = @admin' | sudo tee -a /etc/nix/nix.custom.conf
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

確認:

```bash
nix show-config | grep '^trusted-users'   # → root @admin
```

以降の activation は `nix-community.cachix.org` から fetch する。

## 4. トラブルシュート

### 4.1 activation が失敗した

1. エラーメッセージで「extension <X> has been removed on aarch64-darwin」→ `nix-vscode-extensions` の removed list 該当。`vscode.nix` から削除して再 activation。
2. eval で `infinite recursion` → 直近の module 編集を疑う。`git diff HEAD~1` で範囲を絞る。
3. 完全に動かなくなった → `home-manager generations` で旧 gen を確認し、`/nix/store/<HASH>-home-manager-generation/activate` を直接実行で巻き戻し。

### 4.2 CI が落ちた

| 失敗ステップ                          | 主因 / 対応                                                                                      |
| ------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `Run formatter check`                 | `nix fmt` を走らせて再 commit                                                                    |
| `Lint Brewfile (no vscode entries)`   | `Brewfile` から `vscode "..."` 行を撤去し `modules/programs/vscode.nix` の `extensionIds` に追加 |
| `Run linters (deadnix + shellcheck)`  | `nix run .#lint` をローカルで叩いてエラーを再現、修正                                            |
| `Evaluate home-manager configuration` | platform-mismatch (darwin-only pkg を `cross` に入れた等)。`darwinOnly` に移す                   |
| `Eval determinism gate`               | `builtins.currentTime` / IFD など impurity が混入した。当該 commit を切り戻し                    |
| `Build MEL`                           | MEL essential pkg のいずれかが破損。nixpkgs を一時 pin or 該当 pkg を MEL から外す ADR           |

### 4.3 `git push` が `Device not configured` で fail する

`~/.gitconfig` の credential.helper が brew 由来 path に hardcode された旧症状 (PR #15 で修正済)。再発したら:

```bash
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

で `home.activation.purgeStaleGhCredentialHelper` が走り、HM-managed `~/.config/git/config` の helper を再生する。それでも直らない場合:

```bash
git config --file ~/.gitconfig --unset-all credential.https://github.com.helper
git config --file ~/.gitconfig --unset-all credential.https://gist.github.com.helper
```

### 4.4 dotfiles-sync が動いていない

```bash
launchctl print gui/$(id -u)/dev.egahika.dotfiles-sync   # state 確認
launchctl kickstart -k gui/$(id -u)/dev.egahika.dotfiles-sync   # 強制実行
tail -n20 ~/.cache/dotfiles-sync/{log,err}                # 出力確認
tail -n5 ~/.cache/dotfiles-sync/metrics.jsonl             # 直近結果
```

## 5. 緊急時 / ロールバック

### 5.1 直近の HM 適用を巻き戻す

```bash
home-manager generations | head -3            # 直近 gen を確認
/nix/store/<PREVIOUS-HASH>-home-manager-generation/activate
```

`<PREVIOUS-HASH>` は `home-manager generations` の 2 行目 (1 つ前) の store path。

### 5.2 1 つ前の commit に main を戻す

```bash
git -C ~/dotfiles fetch git@github.com:HikaruEgashira/dotfiles.git main
git -C ~/dotfiles revert <BAD_COMMIT> -m 1     # PR の merge commit なら -m 1
git -C ~/dotfiles push                          # CI 緑で auto-merge
```

### 5.3 cachix substituter trust を撤回

```bash
sudo sed -i '' '/^extra-trusted-users = @admin$/d' /etc/nix/nix.custom.conf
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

これで PR #12 の効果のみ無効化、他の改善は影響なし。

## 6. 新マシン bootstrap (将来の自分のため)

```bash
# 1) Determinate Nix を入れる (curl オフィシャル installer)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2) trusted-users を即足す (Survivor #1 を最初から効かせる)
echo 'extra-trusted-users = @admin' | sudo tee -a /etc/nix/nix.custom.conf
sudo launchctl kickstart -k system/systems.determinate.nix-daemon

# 3) リポを clone & apply
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage --accept-flake-config

# 4) brew 部分 (kext / GUI / vscode 以外の cask)
brew bundle --file=~/dotfiles/Brewfile
```
