# Operations Cookbook

`~/dotfiles` の運用レシピ集。「どう書くか」は `AGENTS.md`、「なぜそう設計したか」は `docs/ideation/` と各 PR description、手順の索引は `docs/playbooks.md`。本ドキュメントは「どう操作するか」のみを扱う。

## 1. 日常運用

| やりたいこと     | コマンド                                           | 備考                                                                                                                                                                                                                                                                                                                            |
| ---------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 設定を反映       | `nix run ~/dotfiles#switch`                        | ユーザー層 (`homeConfigurations.hikae`) を root なしで activate。OS 層に差分がある時だけ `sudo darwin-rebuild switch` が走り Touch ID で承認する                                                                                                                                                                                |
| ledger 棚卸し    | `nix run ~/dotfiles#audit`                         | purpose 別集計 + 全 entry 表 + expires 切れ件数                                                                                                                                                                                                                                                                                 |
| launchd 棚卸し   | `nix run ~/dotfiles#launchd-audit`                 | 野良 agent を `UNKNOWN` 報告。一覧と撤去は `docs/launchd.md`                                                                                                                                                                                                                                                                    |
| XDG 棚卸し       | `nix run ~/dotfiles#xdg-audit`                     | 宣言した entry と live の drift (未移設 / legacy と target の両存 / env 不一致) を報告。entry 自体は `lib/xdg-entries.nix`                                                                                                                                                                                                      |
| 静的検査         | `cd ~/dotfiles && nix run .#lint`                  | statix + deadnix + shellcheck (CI と同一)                                                                                                                                                                                                                                                                                       |
| 整形             | `cd ~/dotfiles && nix fmt`                         | nixfmt + prettier + shfmt                                                                                                                                                                                                                                                                                                       |
| flake gate       | `nix flake check ~/dotfiles --accept-flake-config` | formatter + eval + apps + checks                                                                                                                                                                                                                                                                                                |
| inputs 更新      | `cd ~/dotfiles && nix run .#update`                | 全 inputs を latest に bump + eval gate。`-- --activate` で適用。週次 GH Actions は変更を main に直接 push。手動更新は検証後に commit / push する                                                                                                                                                                               |
| 容量 maintenance | `~/dotfiles/scripts/disk-maintenance.sh --dry-run` | tombstone (退役 tool の state) は毎回消し、空き率が 10% 未満のときだけ nix 世代削除 → GC → optimise → キャッシュ → Codex 旧 release → ゴミ箱 → 30 日起動の無い podman VM の順に回収して目標に届いた時点で止まる。launchd は 6h 毎 + login 時。実削除は `--dry-run` を外す。手元に要らない大物は `--archive PATH` で S3 へ (7.2) |
| 同期実績         | `tail -n5 ~/.cache/dotfiles-sync/metrics.jsonl`    | `outcome / wall_s / head_before / head_after / xdg_drift / pending`。`pending=yes` は「OS 層の build は通ったが未適用」を意味する (ユーザー層は sync が適用済み)。適用は `nix run .#switch`                                                                                                                                     |

clean な `main` は `origin/main` と同じでも build を毎回実行し、失敗時は次回に再試行する。適用は root が要るため自動化せず、`pending=yes` を残すだけに留める。

### 1.1 AI CLI の導入と更新

Codex・Claude Code・OpenCode は Homebrew / Nix package にせず、公式のネイティブインストーラを使う。`nix run .#switch` の home-manager activation が未導入の CLI だけをインストールする。既存の実行ファイルや起動ラッパーは保持し、activation では更新しない。

| CLI         | 導入先                     | 更新               |
| ----------- | -------------------------- | ------------------ |
| Codex       | `~/.local/bin/codex`       | `codex update`     |
| Claude Code | `~/.local/bin/claude`      | `claude update`    |
| OpenCode 2  | `~/.opencode/bin/opencode` | `opencode upgrade` |

導入処理は `modules/programs/ai-cli-install.sh`。初回のみネットワーク接続が必要で、失敗時は activation を失敗させ次回に再試行する。バージョンと自動更新は各 CLI が管理するため、flake の rollback では CLI の版は戻らない。OpenCode は [V2 の公式インストーラ](https://opencode.ai/v2/docs) を使う。Homebrew 版が残っているマシンでは、ネイティブ版の起動確認後に該当パッケージを `brew uninstall` する。`--zap` は設定やセッションを削除し得るため使わない。

Codex の公式 updater は `~/.local/bin/codex` を置き換える。OpenCodex などの外部ツールがこのパスにラッパーを置いている場合、そのツール側で更新後の再登録が必要になる。

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

1. `hosts/<HOST>/default.nix` を新規作成し、`modules/darwin/*` を import する。host 固有の override (proxy / 別 identity / screenlock) もここに書く。
2. `flake.nix` の `darwinConfigurations` に `<HOST> = mkDarwin "aarch64-darwin";` を追加する。`home-manager.users.<user>` と `system.primaryUser` も host 側で切り替える。
3. 新 host で `nix run nix-darwin/master -- switch --flake github:HikaruEgashira/dotfiles#<HOST>`。

### 2.4 XDG entry を足す / 移設する

1. `lib/xdg-entries.nix` の `entries` に `mkEntry` で追記する。eval 時の assert が legacy の相対パス・target の XDG root 配下・env 名・重複を弾く。
2. legacy は `$HOME` 相対で、ドット始まりとは限らない (例: Go の既定 GOPATH は `~/go`)。
3. 移設対象にしてよいのは「そのツールが `$XDG_*_HOME` を尊重する env を持つ」「legacy path を他の module が所有していない」「XDG 非対応の固定 path をツールが持たない」の 3 条件を満たすもの。
   - 除外例: `~/.aws` (`modules/programs/aws.nix` が config を所有し、`sso/` `cli/` の cache は固定 path)、`~/.terraform.d` (terraform が `checkpoint_*` を固定 path に書く)。
4. env を継承しない起動経路 (GUI / launchd) が legacy path を作り直すことがある。ツールが**書かない** config ファイルなら HM が所有してよい (`~/.npmrc` の `cache=` が実例)。ツール自身が書くファイル (`go env -w` の `GOENV`) は綱引きになるので所有しない。
5. `nix run ~/dotfiles#xdg-audit` が exit 0 になることを確認してから commit する。

### 2.5 nixpkgs に無い GUI / kext を足す

1. `modules/darwin/homebrew.nix` の `casks` / `brews` / `masApps` に追加。
2. 直前のコメントに nix 化できない理由を残す (例: `# nixpkgs broken`, `# kext required`)。
3. 次回 switch で `brew bundle` が走る。即時反映だけしたい場合は `brew bundle --file=<generated>` を待たず `nix run .#switch` を回す。
4. nix 化できるようになったら homebrew から削除し `lib/package-registry.nix` に移す。

npm / pypi にしか無い CLI は `writeShellApplication` で `npx --yes pkg@version` / `uvx --from pkg==version` を包む (初回実行時のみネットワーク)。常駐 daemon は npx のキャッシュ path が入れ替わるため、`npm install -g --prefix ~/.local/share/npm-global pkg@version` で固定 prefix に入れ、`~/.local/share/npm-global/bin` を PATH に置く。

## 3. オプトイン機能を有効化する

### 3.0 Firewall posture (module: `modules/darwin/security.nix`)

`networking.applicationFirewall` が activation (root) で global on + stealth on + blockall on を適用し、同じ activation の末尾で実効値を読み戻して検証する。sudoers の追加設定は要らない。

blockall は ALF の非必須な受信を遮断するため、忘れた dev server の `*:PORT` bind は LAN から通常到達できなくなる。ALF だけで全受信を保証せず、必要な受信サービスにも影響する。

確認:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode --getblockall
```

global は `(State = 1)` または `(State = 2)`、stealth は `on`、blockall は `blocking all non-essential incoming connections` を確認する。activation も同じ実効値を検証し、setter 失敗や不一致を終了コード 1 にする (`nix run .#switch` が失敗する)。

一時的に blockall だけを解除する場合 (次回 switch で on に戻る):

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
```

完全に撤回する場合は `networking.applicationFirewall.*` を module から外して switch する。firewall 用の sudoers ルールは持たない (root の activation が直接設定する)。

### 3.1 sudo で Touch ID を使う

`security.pam.services.sudo_local.touchIdAuth` が `/etc/pam.d/sudo_local` を宣言管理する。`reattach` も有効なので tmux / screen 内の sudo でも効く。状態確認は:

```bash
grep -E 'pam_tid|pam_reattach' /etc/pam.d/sudo_local
```

無効化するときは `modules/darwin/security.nix` の該当行を外して switch する。

### 3.2 cachix substituter を実効化

`modules/darwin/nix.nix` の `nix.settings` が `/etc/nix/nix.conf` を生成する (`trusted-users = root @admin` を含む)。手で追記する設定は無い。

確認:

```bash
nix show-config | grep '^trusted-users'   # → root @admin
nix show-config | grep '^substituters'    # → cache.nixos.org と nix-community.cachix.org
```

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

解除: System Settings > General > Device Management から `NextDNS (<profile-id>)` を削除。Wi-Fi service の静的 DNS は `system.activationScripts.wifiDnsFromDhcp` (`modules/darwin/security.nix`) が activation ごとに空へ戻すので手で触らない。

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
   nix run ~/dotfiles#switch
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

### 3.5 macOS 自動アップデートを固定する

`system.defaults.CustomSystemPreferences."com.apple.SoftwareUpdate"` (`modules/darwin/system.nix`) が `/Library/Preferences/com.apple.SoftwareUpdate` を宣言管理する。手で `sudo defaults write` する必要は無い。

確認:

```bash
defaults read /Library/Preferences/com.apple.SoftwareUpdate | grep -E 'AutomaticDownload|AutomaticallyInstallMacOSUpdates|CriticalUpdateInstall'   # すべて 1
```

### 3.7 ARTEX をローカル専用で常駐させる (module: `modules/programs/artex.nix`)

ARTEX と Postgres は loopback (`127.0.0.1:8787` / `:8788` / `:5432`) でしか待ち受けない。Mac は受信を一切公開しない (ALF blockall を維持し、`tailscale serve` / Funnel は使わない)。binary・data・secrets (`local.env`) は `~/.local/share/artex` に置く stateful なファイルで、宣言管理するのは launchd の起動条件だけ。binary を差し替えたら `launchctl kickstart -k gui/$(id -u)/dev.egahika.artex` で再起動する。

確認:

```bash
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(8787|8788|5432) '   # 全て 127.0.0.1
tailscale serve status                                      # No serve config
```

## 4. トラブルシュート

### 共有 skill の名前衝突

`nix run .#skills-audit` は `~/.agents/skills` を Pi の loader で読み、採用された skill と diagnostics を JSON で返す。diagnostics がある場合は終了コード 1。別のディレクトリは `nix run .#skills-audit -- /path/to/skills` で指定する。Pi の個人設定やプロジェクト設定は読み込まないため、対象外の探索先を含む起動時 diagnostics は別途確認する。

`synced/<bucket>/` にある skill の正本は bucket 側とし、同名 skill を top-level に複製しない。`collision.winnerPath` と `collision.loserPath` の内容を確認し、古い top-level のディレクトリを `~/.agents/skills/.trash/<timestamp>/` へ退避する。削除はしない。Pi は dot directory を探索しない。同じ実体への symlink は重複として数えない。

退避後に監査を再実行し、diagnostics が空で、期待する `skills[].filePath` が選ばれたことを確認する。復旧時は退避先から元のパスへ戻す。

### 4.1 switch が失敗した

1. eval で `infinite recursion` → 直近の module 編集を疑う。`git diff HEAD~1` で範囲を絞る。
2. `/etc` の衝突 → `Unexpected files in /etc, aborting activation` が出たら、表示された file を `.before-nix-darwin` に rename して再実行する。nix-darwin は中身が未知の `/etc` を上書きしない。
3. 完全に動かなくなった → §5.1 の手順で層ごとに 1 つ前の generation へ戻す。

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
nix run ~/dotfiles#switch
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

### 4.6 secret を rotate する

`~/.config/secrets/env.age` は age で暗号化した `KEY=value` 行、`~/.config/secrets/age-key.txt` が復号鍵 (0600)。シェルは起動時に `age -d` で復号して export する。復号結果は環境変数として子プロセスへ継承されるため、`_SECRETS_GEN` を持つ親 (herdr / tmux) 配下では再復号しない。

```bash
cd ~/.config/secrets
plain=$(mktemp)
trap 'rm -f "$plain"' EXIT
age -d -i age-key.txt env.age >"$plain"
$EDITOR "$plain"
age -e -r "$(age-keygen -y age-key.txt)" -o env.age "$plain"
```

キー名を増減したら `modules/programs/zsh.nix` の `_SECRETS_GEN` を上げる。番号を据え置くと、古い番号を継承したシェルが新しいキーを永久に読まない。

### 4.7 nix-daemon / `/nix` がおかしい

daemon は nix-darwin 管理 (`org.nixos.nix-daemon`)、`/etc/nix/nix.conf` は `nix.settings` の生成物。

```bash
launchctl print system/org.nixos.nix-daemon | grep -E 'state|program'
nix store ping
sudo launchctl kickstart -k system/org.nixos.nix-daemon   # 設定変更を反映
sudo tail -n50 /var/log/nix-daemon.log                     # logFile 未設定なら unified log: sudo log show --last 5m --predicate 'process == "nix-daemon"'
```

`/nix` が未マウントの場合は、自動解除サービスを確認する。暗号化ボリュームは `fstab` だけでは解除できない。

```bash
sudo launchctl print system/org.nixos.darwin-store
sudo launchctl kickstart system/org.nixos.darwin-store
mount | grep ' /nix '
nix store info
```

`modules/darwin/nix-store.plist` は macOS の `security` と `diskutil` で System Keychain の既存鍵を渡す。鍵を画面やファイルへ出力しない。UUID を service 名とする鍵を先に探し、Determinate installer 由来の `Nix Store` 名の鍵を fallback とする。

サービスが欠落して Nix を起動できない場合は、リポジトリから復旧する:

```bash
sudo install -o root -g wheel -m 644 ~/dotfiles/modules/darwin/nix-store.plist /Library/LaunchDaemons/org.nixos.darwin-store.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.darwin-store.plist
nix store info
nix run ~/dotfiles#switch
```

plist は `/nix` のマウント前に読める実ファイルとして nix-darwin activation が配置する。Determinate の実行ファイルやサービスは復元しない。再起動後に `mount` と `nix store info` を再確認する。

## 5. 緊急時 / ロールバック

### 5.1 直近の switch を巻き戻す

ユーザー層 (root 不要):

```bash
home-manager generations | head -3
/nix/store/<PREVIOUS-HASH>-home-manager-generation/activate
```

OS 層:

```bash
darwin-rebuild --list-generations | head -3   # 直近 gen を確認
sudo darwin-rebuild --rollback                # 1 つ前へ
```

### 5.2 1 つ前の commit に main を戻す

```bash
git -C ~/dotfiles fetch git@github.com:HikaruEgashira/dotfiles.git main
git -C ~/dotfiles revert <BAD_COMMIT> -m 1     # PR の merge commit なら -m 1
git -C ~/dotfiles push                          # CI 緑で auto-merge
```

### 5.3 cachix substituter trust を撤回

`modules/darwin/nix.nix` の `nix.settings` から `nix-community.cachix.org` の substituter / public key を外して switch する (`/etc/nix/nix.conf` は生成物なので直接編集しない)。

## 6. 新マシン bootstrap (将来の自分のため)

```bash
# 1) upstream Nix を入れる (daemon と /nix volume は installer が作る)
curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon

# 2) リポを clone して nix-darwin を適用する
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run nix-darwin/master -- switch --flake ~/dotfiles#hikae

# 3) Homebrew は switch 内の activation が homebrew module 経由で同期する
#    (手で brew bundle は叩かない)
```

## 7. 容量

ディスクは 229G の APFS コンテナ。2026-10-25 の棚卸しで 212G 使用 (空き 17G) だったものを、下記で空き 60G 超まで戻した。再び詰まったら ladder が `report_candidates` で候補を出す。

| 回収経路                            | 対象                                                                                       | 2026-10-25 の回収量 |
| ----------------------------------- | ------------------------------------------------------------------------------------------ | ------------------- |
| ladder (6h 毎、空き 10% 未満で発火) | nix 世代 / GC / 再取得できる cache / Codex 旧 release / ゴミ箱 / 30 日起動の無い podman VM | 数百 MB〜数 GB      |
| tombstone (毎回、空き率に関係なく)  | 退役 tool の state: `~/go`, `~/Library/pnpm`, mise, cask 残骸の `share/`                   | 20G                 |
| 手動 / `--podman-machine NAME`      | 停止済み VM、未宣言 brew formula/cask、project 毎の provider 複製、`.pnpm-store`           | 17G                 |
| `--archive PATH`                    | 唯一のコピーだが手元に要らないもの (artex import、Codex 作業 dir、旧 workspace)            | 13G (S3 へ)         |
| OS (sudo)                           | 適用待ち macOS 更新 (Preboot `cryptex1/proposed`) + Chrome `code_sign_clone`               | 25G (未実施、#166)  |

### 7.1 OS 側 (sudo が要る、ladder の対象外)

Preboot と `/System/Volumes/Update` が膨らむのは適用していない更新が積まれているため。放置すると 20G 前後が常時占有される。

```sh
softwareupdate --list        # 適用待ちを確認 (2026-10-25 時点: macOS Tahoe 26.7.1, 7.4G)
tmutil listlocalsnapshots /  # com.apple.os.update-* が staged 更新の実体
sudo softwareupdate -i 'macOS Tahoe 26.7.1-25G241' --restart
```

スナップショットを先に消すと staged 更新が壊れるので、必ず適用を先に済ませる。

### 7.2 S3 への退避 (`--archive`)

bucket は `hikae-archive-951872725222` (iac-aws `projects/other/archive.tf`)。CLI の default profile (ReadOnlyAccess) に `PutObject` 系だけ bucket policy で足してあり、削除は `hikae-admin-sso` でしかできない。object は GLACIER_IR (即時取得、$4/TB/月)、key は `<hostname>/<HOME からの相対 path>`、directory は `.tar.zst` に固めて置く。

```sh
aws sso login                                                      # 90 日毎
~/dotfiles/scripts/disk-maintenance.sh --archive ~/.local/share/artex/import/opt-artex.tar.zst
aws s3 ls s3://hikae-archive-951872725222/ --recursive             # 一覧
aws s3 cp s3://hikae-archive-951872725222/<key> ./                 # 戻す (GLACIER_IR は restore 不要)
```

upload 後に `head-object` の `ContentLength` と `x-amz-meta-sha256` を手元の値と照合してからローカルを消す。転送中の破損は CLI の full-object checksum が弾く。SSO セッションが要るので launchd からは走らせず、ladder は候補を report に出すだけに留める。

### 7.3 判断が要るもの (2026-10-25 時点で残したもの)

| 対象                                          | 大きさ | 扱い                                                                            |
| --------------------------------------------- | ------ | ------------------------------------------------------------------------------- |
| `jev-kitchen/{.venv-train,train/laya-jp-out}` | 1.9G   | 学習中の venv と出力。`uv sync` で戻るが作業中なので残す                        |
| `~/Documents/Codex/<date>`                    | 3G     | 30 日を過ぎた date folder は dry-run に表示。個別確認後 `--archive PATH` で退避 |
| `gh-intel/packages/{web-qa,identity}/.local`  | 2.6G   | repo の gitignore 対象。repo 側の clean 手順 (#168)                             |
| `~/.cache/incident-2026-10-25-actions-runner` | 456M   | runner 事故 (#150) の証跡。post-mortem 後に消す                                 |
| `/private/var/db/{diagnostics,uuidtext}`      | 1.7G   | unified log。`sudo log erase --all` で消えるが調査用に残す                      |

`disk-maintenance.sh --dry-run` は空き率が目標以上でも、`Documents/Codex/YYYY-MM-DD` のうち30日より古いものを archive 候補として表示する。自動退避・削除はしない。pnpm の project-local `.pnpm-store` は tombstone に加えない。`modules/programs/ai-sandbox.nix` は現在 `$HOME` を writable に含めるため `~/.local/share/pnpm` はその範囲内だが、fallback の実行時原因は未確認 (#175)。
