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
| mise trust     | `~/.local/bin/mise-trust-repo <repo>`                           | `~/ghq` 配下は config で trust 済み。外側の checkout は hooks が自動実行 (`docs/operations.md` §4.6)                                                            |
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
curl -sL https://test.nextdns.io                   # → "status":"ok", "protocol":"DOH", "deviceName":"<device-name>"
dscacheutil -q host -a name whoami.akamai.net      # → NextDNS node (ISP 61.122.125.x / 163.139.x.x 以外)
```

`dig` / `nslookup` は mDNSResponder を迂回して UDP/53 を直接叩くため profile の効果を観測できない。system resolver を通す `dscacheutil` か `curl` で見る。UCG 側の Encrypted DNS は `dig @192.168.1.1 +short whoami.akamai.net` で観測できる。

UCG の Encrypted DNS は LAN 発の平文 53 を宛先に関わらず gateway に引き込むため、DNS を固定している端末 (Google Cast 等) も NextDNS に乗る。迂回経路として残るのは端末自身の DoT (853) / DoH のみで、DoT は UCG firewall で LAN→WAN tcp/853 を drop すれば塞げる。Tailscale は tailnet 設定で同じ NextDNS DoH を global resolver にしてあるので、有効化しても経路は変わらない (`clientName: tailscale` で観測)。

解除: System Settings > General > Device Management から `NextDNS (<profile-id>)` を削除。Wi-Fi service の静的 DNS は `home.activation.wifiDnsFromDhcp` (`modules/programs/security.nix`) が activation ごとに空へ戻すので手で触らない。

### 3.4 署名鍵をローテーションする

署名鍵は agent が保持し、git は `key::<公開鍵>` (agent 委譲) で署名する。鍵を替えるときは **公開鍵が 2 箇所 (`signing.key` と `allowedSigners`) の単一 let に集約されている**ので、`modules/programs/git.nix` の `signingPubKey` 1 行だけ書き換える。

1. 新しい鍵を作る (署名専用。SSH 認証には使わない):

   ```bash
   ssh-keygen -t ed25519 -C "$(git config user.email)" -f ~/.ssh/id_ed25519_new
   ```

2. GitHub に **Signing Key 種別**で登録する (auth key とは別枠。Web UI か下記):

   ```bash
   gh auth refresh -h github.com -s admin:ssh_signing_key   # token scope 追加
   gh api -X POST /user/ssh_signing_keys -f title="$(hostname -s)" -f key="$(cat ~/.ssh/id_ed25519_new.pub)"
   ```

3. `modules/programs/ssh.nix` の `keyFile` と `modules/programs/git.nix` の `signingPubKey` を新鍵に更新し、適用する:

   ```bash
   nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
   launchctl kickstart -k gui/$(id -u)/dev.egahika.ssh-add
   ```

4. 検証 (3 経路すべて):

   ```bash
   git commit --allow-empty -m "signing key check"
   git log -1 --show-signature          # → Good "git" signature for <user noreply email>
   gh api repos/HikaruEgashira/dotfiles/commits/$(git rev-parse HEAD) --jq .commit.verification
   ~/.config/ai-sandbox/bin/codex sandbox -- /bin/sh -c 'git -C ~ verify-commit HEAD'   # sandbox 内でも鍵ファイルを読まずに署名できる
   ```

5. 旧鍵を GitHub と端末から消す (旧鍵の失効は取り消せないので、検証が通ってから):

   ```bash
   gh api -X DELETE /user/ssh_signing_keys/<id>
   rm ~/.ssh/id_ed25519_new  # 不要になった方
   ```

`allowed_signers` は repo 管理 (公開情報) で、commit email を principal にしている。principal を変えない限り GitHub 側の verified 表示はアカウント登録鍵だけで決まる。

### 3.5 macOS 自動アップデートを固定する (sudo 必須・未自動化)

`/Library/Preferences/com.apple.SoftwareUpdate` が正で、書き込みに root が要るため activation には入れていない。新マシンで一度だけ:

```bash
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
```

確認:

```bash
defaults read /Library/Preferences/com.apple.SoftwareUpdate | grep -E 'AutomaticDownload|AutomaticallyInstallMacOSUpdates|CriticalUpdateInstall'   # すべて 1
```

### 3.6 self-hosted runner を登録する (macOS 端末ごとに一度)

`activation-darwin` (`.github/workflows/activation-darwin.yml`) は label `hikae` の self-hosted runner で **aarch64-darwin の activation を build** し、flake.lock bump が壊していれば `scripts/flake-lock-repair.sh` が main を 1 commit 戻す。linux CI は eval 止まりなので、build 破壊を捕まえられるのはここだけ。

登録 (runner 本体は自己更新するため `~/actions-runner` に置き、plist は `modules/programs/github-runner.nix` の宣言管理):

```bash
name=$(hostname -s)
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -sSL -o runner.tar.gz https://github.com/actions/runner/releases/download/v2.338.0/actions-runner-osx-arm64-2.338.0.tar.gz
tar xzf runner.tar.gz && rm runner.tar.gz
./config.sh --unattended --replace --url https://github.com/HikaruEgashira/dotfiles \
  --token "$(gh api -X POST repos/HikaruEgashira/dotfiles/actions/runners/registration-token --jq .token)" \
  --name "$name" --labels hikae --work _work
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

確認:

```bash
gh api repos/HikaruEgashira/dotfiles/actions/runners --jq '.runners[] | "\(.name) \(.status)"'
launchctl print gui/$(id -u)/dev.egahika.github-runner | grep state
```

解除 (登録 token は 1 時間で失効するので secret 管理は不要):

```bash
name=$(hostname -s)
launchctl bootout gui/$(id -u)/dev.egahika.github-runner
gh api -X DELETE "repos/HikaruEgashira/dotfiles/actions/runners/$(gh api repos/HikaruEgashira/dotfiles/actions/runners --jq ".runners[] | select(.name==\"$name\") | .id")"
rm -rf ~/actions-runner
```

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
| `activation-darwin` (self-hosted)     | 実端末の build 失敗。flake.lock bump なら workflow が自動 revert、それ以外は §5.2      |

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

### 4.5 `opencode` / `opencode2` が無言でハングする (managed service の stale PID)

opencode v2 は background service (既定 `127.0.0.1:49374`) 経由で TUI を描画する。`~/.local/state/opencode/service.json` の `pid` が死んでいるのに、別の orphan `opencode serve --service` が port を掴んでいると、起動ごとに service 生成 → bind 失敗 → retry を繰り返し、TUI は空画面のまま返らない。

interactive shell では `modules/programs/opencode/preflight.sh` が `opencode` / `opencode2` を包み、起動前に「`service.json` の pid は死んでいるのに port は LISTEN」の不一致を検出して orphan を落とし `service restart` するため、通常は手当て不要。同じ script を `~/.local/bin/opencode-health` として実行でき、launchd (`dev.egahika.opencode-service-health`) が毎日 09:05 に叩き、結果を `~/.cache/opencode-service-health.{log,err}` に残す。orphan が SIGTERM を無視した場合は SIGKILL に escalate し、それでも port が空かなければ TUI を起動せずエラーを返す。以下は preflight を無効化している場合や、PATH に `~/.local/bin` が無い script から `opencode run` を直接叩く場合の復旧手順。

```bash
lsof -nP -iTCP:49374 | grep LISTEN        # 掴んでいる pid を特定
kill <pid>                                # orphan を落とす
opencode service restart && opencode service status
```

判定: `~/.local/share/opencode/log/opencode.log` に `Managed service port 49374 ... already in use` が連続していたらこれ。`opencode service status` が `stopped` でも port が埋まっていれば orphan 確定。

upstream (`sst/opencode`) への issue は当面立てない。preflight が interactive の主経路を自己修復し、上流の恒久修正 (stale `service.json` を検知して orphan を落とす) は調査コストが大きいため。再発が続くか非 interactive 経路で実害が出たら起票する。

### 4.6 `git commit` が mise untrusted で止まる

`~/ghq` 配下の checkout は `~/.config/mise/conf.d/trust.toml` の `trusted_config_paths` で最初から trust される。`~/ghq` の外にある checkout は global `post-checkout` / `post-merge` / `pre-commit` が `~/.local/bin/mise-trust-repo` を実行して repo 単位で trust する。

手動で直す場合:

```bash
~/.local/bin/mise-trust-repo "$(git rev-parse --show-toplevel)"
mise trust --show
```

pre-commit の secret scan は「untrusted による rc 1」を検出 (findings) と区別し、scan を skip して local hook へ進む。untrusted を理由に `--no-verify` で検査ごと飛ばさない。

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
