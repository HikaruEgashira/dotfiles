# Operations Cookbook

`~/dotfiles` の運用レシピ集。「どう書くか」は `AGENTS.md`、「なぜそう設計したか」は `docs/ideation/` と各 PR description、手順の索引は `docs/playbooks.md`。本ドキュメントは「どう操作するか」のみを扱う。

## 1. 日常運用

| やりたいこと   | コマンド                                                        | 備考                                                                                                                                                            |
| -------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 設定を反映     | `nix run ~/dotfiles#homeConfigurations.hikae.activationPackage` | 冪等。`--accept-flake-config` は trusted-users 設定後は不要                                                                                                     |
| ledger 棚卸し  | `nix run ~/dotfiles#audit`                                      | purpose 別集計 + 全 entry 表 + expires 切れ件数                                                                                                                 |
| launchd 棚卸し | `nix run ~/dotfiles#launchd-audit`                              | 野良 agent を `UNKNOWN` 報告。一覧と撤去は `docs/launchd.md`                                                                                                    |
| XDG 棚卸し     | `nix run ~/dotfiles#xdg-audit`                                  | 宣言した entry と live の drift (未移設 / legacy と target の両存 / env 不一致) を報告。entry 自体は `lib/xdg-entries.nix`                                      |
| 静的検査       | `cd ~/dotfiles && nix run .#lint`                               | statix + deadnix + shellcheck (CI と同一)                                                                                                                       |
| 整形           | `cd ~/dotfiles && nix fmt`                                      | nixfmt + prettier + shfmt                                                                                                                                       |
| flake gate     | `nix flake check ~/dotfiles --accept-flake-config`              | formatter + eval + apps + checks                                                                                                                                |
| inputs 更新    | `cd ~/dotfiles && nix run .#update`                             | 全 inputs を latest に bump + eval gate。`-- --activate` で適用。週次 GH Actions は変更を main に直接 push。手動更新は検証後に commit / push する               |
| 同期実績       | `tail -n5 ~/.cache/dotfiles-sync/metrics.jsonl`                 | `outcome / wall_s / head_before / head_after / xdg_drift`。`xdg_drift` は同期後の XDG entry 監査結果 (`none`/`drift`/`unknown`/`not-run`、同期の成否は変えない) |

clean な `main` は `origin/main` と同じでも activation を毎回実行し、失敗時は次回に再試行する。

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

### 2.3 新しい host (2 台目以降) を足す

1. `hosts/<HOST>/default.nix` を新規作成。host 固有の override (proxy / 別 identity / screenlock) を書く。
2. `flake.nix` の `mkConfig` を host / system 引数化し、`homeConfigurations` に `<HOST>` エントリを追加する。
3. 新 host で `nix run github:HikaruEgashira/dotfiles#homeConfigurations.<HOST>.activationPackage`。

### 2.4 XDG entry を足す / 移設する

1. `lib/xdg-entries.nix` の `entries` に `mkEntry` で追記する。eval 時の assert が legacy の相対パス・target の XDG root 配下・env 名・重複を弾く。
2. legacy は `$HOME` 相対で、ドット始まりとは限らない (例: Go の既定 GOPATH は `~/go`)。
3. 移設対象にしてよいのは「そのツールが `$XDG_*_HOME` を尊重する env を持つ」「legacy path を他の module が所有していない」「XDG 非対応の固定 path をツールが持たない」の 3 条件を満たすもの。
   - 除外例: `~/.aws` (`modules/programs/aws.nix` が config を所有し、`sso/` `cli/` の cache は固定 path)、`~/.terraform.d` (terraform が `checkpoint_*` を固定 path に書く)。
4. env を継承しない起動経路 (GUI / mise 経由) が legacy path を作り直すことがある。ツールが**書かない** config ファイルなら HM が所有してよい (`~/.npmrc` の `cache=` が実例)。ツール自身が書くファイル (`go env -w` の `GOENV`) は綱引きになるので所有しない。
5. `nix run ~/dotfiles#xdg-audit` が exit 0 になることを確認してから commit する。

### 2.5 nixpkgs に無い GUI / kext を足す

1. `Brewfile` に `cask "<NAME>"` で追加。
2. 直前のコメント行に nix 化できない理由を残す (例: `# nixpkgs broken`, `# kext required`)。
3. nix 化できるようになったら Brewfile から削除し `lib/package-registry.nix` に移す。

## 3. オプトイン機能を有効化する

### 3.0 Firewall posture (module: `modules/programs/security.nix`)

activation が毎回適用できるように、各実機で一度だけ3つの setter に引数まで限定した passwordless sudo を許可する。既存の広い規則があれば追記せず、下記3行だけに置き換える:

```bash
sudo visudo -f /etc/sudoers.d/firewall
```

ファイルの内容:

```sudoers
hikae ALL=(root) NOPASSWD: /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
hikae ALL=(root) NOPASSWD: /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
hikae ALL=(root) NOPASSWD: /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on
```

activation で適用される内容: global on + stealth on + blockall on。blockall は ALF の非必須な受信を遮断するため、忘れた dev server の `*:PORT` bind は LAN から通常到達できなくなる。ALF だけで全受信を保証せず、必要な受信サービスにも影響する。

activation を待たず今すぐ適用する場合:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on
```

確認:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode --getblockall
```

global は `(State = 1)` または `(State = 2)`、stealth は `on`、blockall は `blocking all non-essential incoming connections` を確認する。activation も同じ実効値を検証し、setter失敗や不一致を終了コード1にする。

一時的に blockall だけを解除する場合（次回 activation で on に戻る）:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
```

完全に撤回する場合は、module の変更を git で戻し、記録した変更前の3値へ復元してから、不要になった `/etc/sudoers.d/firewall` の3規則を削除する。

### 3.1 sudo で Touch ID を使う

```bash
~/dotfiles/scripts/sudo-touchid.sh status
~/dotfiles/scripts/sudo-touchid.sh enable
```

無効化するとき:

```bash
~/dotfiles/scripts/sudo-touchid.sh disable
```

このスクリプトは macOS Ventura+ の `/etc/pam.d/sudo_local` を更新する (OS 更新で上書きされない)。旧 `/etc/pam.d/sudo` 内の inline 行は enable / disable 時に掃除する。

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

### 3.3 Encrypted DNS (NextDNS DoH profile)

ISP (ARTERIA/UCOM) は宛先を問わず UDP/TCP 53 を網内で透過傍受するため、平文 DNS の指定先は無意味。暗号化経路のみ有効。

| 範囲                  | 手段                                                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 自宅 LAN 全体         | UCG: Settings → Security → Protection → Encrypted DNS → Custom に DoH stamp (`sdns://`, host `dns.nextdns.io`, path `/<profile-id>`) を投入 |
| この Mac (外出先含む) | 下記 profile。profile ID は公開 repo に置かず引数で渡す                                                                                     |

```bash
bash ~/dotfiles/modules/settings/nextdns-profile.sh <profile-id>
# System Settings > General > Device Management で承認
```

確認:

```bash
curl -s https://test.nextdns.io          # → "status":"ok", "profile":"<profile-id>"
dig +short whoami.akamai.net             # → ISP (61.122.125.x) 以外
```

解除: System Settings > General > Device Management から `NextDNS (<profile-id>)` を削除。Wi-Fi service の静的 DNS (`networksetup -setdnsservers Wi-Fi ...`) は DHCP 既定のまま触らない。

## 4. トラブルシュート

### 4.1 activation が失敗した

1. eval で `infinite recursion` → 直近の module 編集を疑う。`git diff HEAD~1` で範囲を絞る。
2. 完全に動かなくなった → `home-manager generations` で旧 gen を確認し、`/nix/store/<HASH>-home-manager-generation/activate` を直接実行で巻き戻し。

### 4.2 CI が落ちた

| 失敗ステップ                          | 主因 / 対応                                                                            |
| ------------------------------------- | -------------------------------------------------------------------------------------- |
| `Run formatter check`                 | `nix fmt` を走らせて再 commit                                                          |
| `Run linters (deadnix + shellcheck)`  | `nix run .#lint` をローカルで叩いてエラーを再現、修正                                  |
| `Evaluate home-manager configuration` | platform-mismatch (darwin-only pkg を `cross` に入れた等)。`darwinOnly` に移す         |
| `Eval determinism gate`               | `builtins.currentTime` / IFD など impurity が混入した。当該 commit を切り戻し          |
| `Build MEL`                           | MEL essential pkg のいずれかが破損。nixpkgs を一時 pin or 該当 pkg を MEL から外す ADR |

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

# 4) brew 部分 (kext / GUI / cask)
brew bundle --file=~/dotfiles/Brewfile
```
