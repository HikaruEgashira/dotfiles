# Operations Cookbook

`~/dotfiles` の運用レシピ集。「どう書くか」は `AGENTS.md`、「なぜそう設計したか」は `docs/ideation/` と各 PR description、手順の索引は `docs/playbooks.md`。本ドキュメントは「どう操作するか」のみを扱う。

## 1. 日常運用

| やりたいこと     | コマンド                                           | 備考                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 設定を反映       | `nix run ~/dotfiles#switch`                        | ユーザー層 (`homeConfigurations.hikae`) を root なしで activate。OS 層に差分がある時だけ `sudo darwin-rebuild switch` が走り Touch ID で承認する                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ledger 棚卸し    | `nix run ~/dotfiles#audit`                         | purpose 別集計 + 全 entry 表 + expires 切れ件数。続けて gh extension の実行ファイルを検証し、dangling symlink や実行ファイル欠落があれば終了コード 1 (復旧は 4.8)                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| launchd 棚卸し   | `nix run ~/dotfiles#launchd-audit`                 | 野良 agent を `UNKNOWN` 報告。一覧と撤去は `docs/launchd.md`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| XDG 棚卸し       | `nix run ~/dotfiles#xdg-audit`                     | 宣言した entry と live の drift (未移設 / legacy と target の両存 / env 不一致) を報告。entry 自体は `lib/xdg-entries.nix`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 静的検査         | `cd ~/dotfiles && nix run .#lint`                  | statix + deadnix + shellcheck (CI と同一)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| 整形             | `cd ~/dotfiles && nix fmt`                         | nixfmt + prettier + shfmt                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| flake gate       | `nix flake check ~/dotfiles --accept-flake-config` | formatter + eval + apps + checks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| inputs 更新      | `cd ~/dotfiles && nix run .#update`                | 全 inputs を latest に bump + substitutable gate (1.3)。`-- --activate` で適用。週次 GH Actions は同じ gate を通した変更だけを main に直接 push。手動更新は検証後に commit / push する                                                                                                                                                                                                                                                                                                                                                                                                                          |
| cache 検査       | `cd ~/dotfiles && nix run .#substitutable-gate`    | 現 lock で darwin system + home activation の閉包に cache.nixos.org から取れない package が無いことを確認する (1.3)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 容量 maintenance | `~/dotfiles/scripts/disk-maintenance.sh --dry-run` | tombstone (退役 tool の state、`~/ghq` 配下の `.pnpm-store`) は毎回消し、artex / containers / `Documents/Codex` の大きさを週次で `~/.local/state/disk-maintenance/sizes.tsv` に記録する。空き率が 10% 未満のときだけ nix GC (30d より古い世代込み) → optimise → キャッシュ (artex `import/` 含む) → Codex 旧 release → artex deploy 世代 (`backups/` `deploy-staging/` の新しい 2 つ以外) → ゴミ箱 → podman (未使用 image/container、30 日起動の無い VM) の順に回収して目標に届いた時点で止まる。launchd は 6h 毎 + login 時。実削除は `--dry-run` を外す。手元に要らない大物は `--archive PATH` で S3 へ (7.2) |
| ghq clone 棚卸し | `~/dotfiles/scripts/ghq-clean.py --dry-run`        | clone root と upstream 無し branch / local-only commit を表示し、どちらかがある clone は `--allow-unpushed` を付けない限り保護する。定期実行も dry-run のみ。詳細と明示削除手順は 7.4                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 同期実績         | `tail -n5 ~/.cache/dotfiles-sync/metrics.jsonl`    | `outcome / wall_s / head_before / head_after / xdg_drift / pending`。`pending=yes` は「OS 層の build は通ったが未適用」を意味する (ユーザー層は sync が適用済み)。適用は `nix run .#switch`                                                                                                                                                                                                                                                                                                                                                                                                                     |

clean な `main` は `origin/main` と同じでも build を毎回実行し、失敗時は次回に再試行する。適用は root が要るため自動化せず、`pending=yes` を残すだけに留める。

### 1.1 AI CLI の導入と更新

Codex・Claude Code・OpenCode は Nix package にせず、公式のネイティブインストーラを使う。`nix run .#switch` の home-manager activation が未導入の CLI だけをインストールする。既存の実行ファイルや起動ラッパーは保持し、activation では更新しない。

| CLI         | 導入先                     | 更新               |
| ----------- | -------------------------- | ------------------ |
| Codex       | `~/.local/bin/codex`       | `codex update`     |
| Claude Code | `~/.local/bin/claude`      | `claude update`    |
| OpenCode 2  | `~/.opencode/bin/opencode` | `opencode upgrade` |

導入処理は `modules/programs/harness/ai-cli-install.sh`。初回のみネットワーク接続が必要で、失敗時は activation を失敗させ次回に再試行する。バージョンと自動更新は各 CLI が管理するため、flake の rollback では CLI の版は戻らない。OpenCode は [V2 の公式インストーラ](https://opencode.ai/v2/docs) を使う。

Codex の公式 updater は `~/.local/bin/codex` を置き換える。OpenCodex などの外部ツールがこのパスにラッパーを置いている場合、そのツール側で更新後の再登録が必要になる。

### 1.2 cache に無い package

| 所有              | 対象                                          | 検証                                            |
| ----------------- | --------------------------------------------- | ----------------------------------------------- |
| Nix binary cache  | `arm-none-eabi-gcc`, `iverilog`, Ghostty      | `cache.nixos.org` の output                     |
| Aqua              | `gws`, `gt`, `higgsfield`, `sisakulint`, `bw` | pin した release asset と `aqua-checksums.json` |
| system activation | Tailscale, Xcode, Bitwarden                   | pkg/MAS と app の署名                           |

Aqua は `~/.local/share/aquaproj-aqua/bin` に proxy だけを作り、初回実行時に asset を取得する。`AQUA_ENFORCE_CHECKSUM` と `AQUA_ENFORCE_REQUIRE_CHECKSUM` は常に有効。system app は存在しない時だけ固定 installer から導入し、既存 app の更新や downgrade はしない。

### 1.3 substitutable gate (`scripts/substitutable-gate.sh`)

inputs を bump した lock が「ローカル source build 禁止」を守っているかを、適用前に判定する。`nix build --dry-run --option substituters https://cache.nixos.org` で `darwinConfigurations.hikae.system` と `homeConfigurations.hikae.activationPackage` の閉包を評価し、「will be built」に残る derivation を `nix derivation show` で分類する。

| 分類  | 判定                                              | 扱い                                                                                       |
| ----- | ------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| glue  | `src` / `srcs` / `outputHash` を持たない          | 件数だけ報告                                                                               |
| fetch | fixed-output (`outputHash`)。hash 固定の download | 件数だけ報告                                                                               |
| build | `src` または `srcs` を持つ                        | `scripts/substitutable-gate-allow.txt` の regex に合えば理由つきで許可、残りを列挙して失敗 |

「will be built = 0 件」は assert しない。nix-darwin / home-manager の生成物 (`darwin-system-*`, `home-manager-generation`, `etc`, `launchd`, `hm_*` など 190 件前後) は repo の内容と inputs の hash を埋め込むため bump のたびに必ずローカルで作り直され、cache には存在し得ない。これらは bash が store path を並べるだけの derivation で、source build ではない。

本機の `/nix/store` に既にある path は dry-run に出ないため、評価は空の chroot store (`~/.cache/substitutable-gate/store`、`SUBSTITUTABLE_GATE_STORE` で変更) で行い、CI runner と同じ判定にする。初回は flake inputs の source (約 700MB) をそこへ copy するので 1 分前後かかる。

allowlist は「cache に無いと分かっていて持っているもの」の台帳で、各行に理由と Issue を書く。2026-11-03 時点: registry の上流 binary (dagger / herdr / pleno-dlp / say-hook / oh-my-pi / node-darwin-arm64)、Cica font。

| 実行場所                           | 対象                                             | 備考                                                                                                                |
| ---------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| 本機 `nix run .#update`            | darwin system + home activation (aarch64-darwin) | gate が落ちたら flake.lock は bump 済みのまま残る。`git checkout flake.lock` で戻すか、原因 package を 2.5 へ逃がす |
| `flake-update.yml` (aarch64-linux) | 同じ 2 target                                    | dry-run は eval と cache 問い合わせだけなので runner の system に依存しない。落ちたら push せず workflow が赤になる |
| `ci.yml`                           | 対象外                                           | PR では lock が変わらない。package 追加時の cache 有無は `nix run .#substitutable-gate` を手で回す                  |

`workflow_dispatch` の `dry_run=true` は bump と gate だけ走らせ push しない。gate 自体の動作確認に使う。

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

### 2.5 Nix cache に output が無い package を足す

1. upstream が CLI の release binary を出しているなら `modules/programs/aqua/registry.yaml` と `aqua.yaml` に追加する。
2. `AQUA_POLICY_CONFIG=modules/programs/aqua/aqua-policy.yaml aqua update-checksum --config modules/programs/aqua/aqua.yaml --prune` で checksum を更新する。
3. GUI は上流署名済み installer を使い、root が要る pkg/MAS は `modules/darwin/native-apps/` に置いて hash・bundle ID・Team ID を検証する。
4. upstream binary がなく Nix cache にも output がない package は追加しない。

npm / pypi にしか無い CLI は `writeShellApplication` で `npx --yes pkg@version` / `uvx --from pkg==version` を包む (初回実行時のみネットワーク)。常駐 daemon は npx のキャッシュ path が入れ替わるため、`npm install -g --prefix ~/.local/share/npm-global pkg@version` で固定 prefix に入れ、`~/.local/share/npm-global/bin` を PATH に置く。

### 2.6 repo に secret を渡す (module: `modules/programs/direnv.nix`)

secret は `~/.config/secrets/env.age` にだけ置き、必要な repo の `.envrc` に `use secrets` で宣言する。direnv の stdlib 拡張 (`modules/programs/direnv/use_secrets.sh`) が env.age を復号し、引数のキーだけを export する。引数を省くと全キーを export するので、原則キー名を書く。`FLATT_GUARD_TOKEN` を渡すと `UV_INDEX_URL` も派生する。

```bash
cd <repo>
printf 'use secrets FLATT_GUARD_TOKEN\n' >>.envrc
direnv allow
```

- `.envrc` は `~/.config/git/ignore` (`modules/programs/git.nix` の `ignores`) に登録済みで、repo の gitignore に足す必要は無い。commit したい repo では `git add -f` する。
- secret はそのディレクトリ配下のシェルと、そこから起動した子プロセスだけが持つ。`zsh -ic` や別ディレクトリのエージェントには渡らない。
- 無いキーを指定すると `use_secrets` は非 0 で終わり、direnv が `.envrc` 全体の読み込みを失敗扱いにする。typo はここで気づく。
- 既存の `.envrc` を宣言管理で書き換えることはしない。secret が無くて困った repo に 1 行足していく。

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

NextDNS 管理画面から DoH の `.mobileconfig` を取得してインストールし、System Settings > General > Device Management で承認する。

確認:

```bash
curl -sL https://test.nextdns.io                   # → "status":"ok", "protocol":"DOH", "deviceName":"<device-name>"
dscacheutil -q host -a name whoami.akamai.net      # → NextDNS node (ISP 61.122.125.x / 163.139.x.x 以外)
```

`dig` / `nslookup` は mDNSResponder を迂回して UDP/53 を直接叩くため profile の効果を観測できない。system resolver を通す `dscacheutil` か `curl` で見る。UCG 側の Encrypted DNS は `dig @192.168.1.1 +short whoami.akamai.net` で観測できる。

UCG の Encrypted DNS は LAN 発の平文 53 を宛先に関わらず gateway に引き込むため、DNS を固定している端末 (Google Cast 等) も NextDNS に乗る。迂回経路として残るのは端末自身の DoT (853) / DoH のみで、DoT は UCG firewall で LAN→WAN tcp/853 を drop すれば塞げる。Tailscale は tailnet 設定で同じ NextDNS DoH を global resolver にしてあるので、有効化しても経路は変わらない (`clientName: tailscale` で観測)。

解除: System Settings > General > Device Management から `NextDNS (<profile-id>)` を削除。Wi-Fi service の静的 DNS は `system.activationScripts.wifiDnsFromDhcp` (`modules/darwin/security.nix`) が activation ごとに空へ戻すので手で触らない。

### 3.4 SSH 鍵の役割分担とローテーション

鍵は用途で 2 本に分け、agent も 2 本立てる (`modules/programs/ssh.nix`)。

| 鍵                       | agent (launchd label)        | socket                               | 用途                          | sandbox                    |
| ------------------------ | ---------------------------- | ------------------------------------ | ----------------------------- | -------------------------- |
| `~/.ssh/id_ed25519`      | `dev.egahika.ssh-agent`      | `~/.local/state/ssh-agent.sock`      | ssh 認証 (vultr, `*.exe.xyz`) | 非公開                     |
| `~/.ssh/id_ed25519_sign` | `dev.egahika.ssh-sign-agent` | `~/.local/state/ssh-sign-agent.sock` | git commit 署名のみ           | `SSH_AUTH_SOCK` として公開 |

host の `SSH_AUTH_SOCK` は認証 agent を指す。git は `gpg.ssh.program` の wrapper が `SSH_AUTH_SOCK` を署名 agent に差し替えて `ssh-keygen` を呼ぶので、host でも sandbox でも署名は署名 agent で行う。sandbox (`ai-sandbox.nix`) は署名 socket だけを allowlist に入れるため、sandbox 内から認証鍵で ssh できない。署名鍵はどの host の `authorized_keys` にも登録しない。

署名公開鍵は `modules/programs/git.nix` の `signingPubKey` 1 箇所に集約している (`signing.key` と `allowedSigners` の両方が参照)。`legacySigningPubKey` は旧署名鍵 (= 現認証鍵) で、過去 commit のローカル検証用に `allowedSigners` に残す。

#### 署名鍵の再生成 (紛失・漏洩時)

1. 鍵を作る:

   ```bash
   ssh-keygen -t ed25519 -C "sign@hikae" -N "" -f ~/.ssh/id_ed25519_sign
   ```

2. GitHub に **Signing Key 種別**で登録する。ghtkn の token に `admin:ssh_signing_key` が無い場合は https://github.com/settings/ssh/new で Key type を Signing Key にして貼る:

   ```bash
   gh api -X POST /user/ssh_signing_keys -f title="$(hostname -s)-sign" -f key="$(cat ~/.ssh/id_ed25519_sign.pub)"
   ```

3. `signingPubKey` を新公開鍵に書き換えて merge し、Home Manager を適用して署名 agent に再ロードする:

   ```bash
   nix run .#homeConfigurations.hikae.activationPackage
   launchctl kickstart -k gui/$(id -u)/dev.egahika.ssh-sign-agent
   launchctl kickstart -k gui/$(id -u)/dev.egahika.ssh-sign-add
   ```

4. 検証:

   ```bash
   SSH_AUTH_SOCK=~/.local/state/ssh-sign-agent.sock ssh-add -l   # sign@hikae のみ
   SSH_AUTH_SOCK=~/.local/state/ssh-agent.sock ssh-add -l        # id_ed25519 のみ
   git commit --allow-empty -m "signing key check" && git log -1 --show-signature && git reset --hard HEAD~1
   ```

5. 漏洩時は旧鍵を GitHub から消す (`gh api /user/ssh_signing_keys` で id を引いて `-X DELETE`)。消すと旧鍵で署名した commit は GitHub 上で unverified に戻る。

#### 認証鍵の再生成

`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519` で作り直し、各 host の `~/.ssh/authorized_keys` を差し替え、`launchctl kickstart -k gui/$(id -u)/dev.egahika.ssh-add` で再ロードする。認証鍵は署名に使わないので git 設定は変えない。

### 3.5 macOS 自動アップデートを固定する

`modules/darwin/system.nix` の activation script が `/Library/Preferences/com.apple.SoftwareUpdate` を宣言管理する (`system.defaults.CustomSystemPreferences` は root の `~/Library/Preferences` に書くだけで実効値に届かないため使わない)。手で `sudo defaults write` する必要は無い。check と download は自動、macOS 本体の install は手動 (再起動を伴うため、§7.1 の月次 window で適用する)。

確認:

```bash
defaults read /Library/Preferences/com.apple.SoftwareUpdate | grep -E 'AutomaticCheckEnabled|AutomaticDownload|AutomaticallyInstallMacOSUpdates|CriticalUpdateInstall'
# AutomaticCheckEnabled = 1, AutomaticDownload = 1, AutomaticallyInstallMacOSUpdates = 0, CriticalUpdateInstall = 1
```

### 3.7 ARTEX をローカル専用で常駐させる (module: `modules/programs/artex.nix`)

ARTEX は loopback (`127.0.0.1:8787` / `:8788`) でしか待ち受けない。Mac は受信を一切公開しない (ALF blockall を維持し、`tailscale serve` / Funnel は使わない)。binary・data・secrets (`local.env`) は `~/.local/share/artex` に置く stateful なファイルで、宣言管理するのは launchd の起動条件だけ。binary を差し替えたら `launchctl kickstart -k gui/$(id -u)/dev.egahika.artex` で再起動する。

Postgres は TCP を待ち受けず、unix socket `~/.local/share/artex/run/` (0700) だけで受ける。認証は `modules/programs/artex/pg_hba.conf` が宣言する `local all all scram-sha-256` で、superuser `artex` の password は `~/.local/share/artex/local.env` の `ARTEX_PG_DSN` にだけ置く (URL の host 部を空にし、`?host=<socket dir>&sslmode=disable` で socket を指す)。`local.env` は wrapper が `KEY=VALUE` 行としてだけ読む (`modules/programs/artex/load-env.sh`、shell 評価はしない。両端の quote は外す)。shell 構文の行があると起動前に fail する。この socket dir は ai-sandbox の `unixSockets` に載せていないので、sandbox 内 agent は DB に到達できない。launchd の wrapper は起動毎に `~/.local/share/artex/pg/pg_hba.conf` を repo 宣言と比較し、違えば上書きしてから postgres を起動する (drift の修復ログは `pg.log`)。停止時は launchd の SIGTERM を wrapper が SIGINT (fast shutdown) に変換し、`ExitTimeOut` 60s 内に checkpoint を終えて止まる。

接続:

```bash
. ~/dotfiles/modules/programs/artex/load-env.sh; load_env_file ~/.local/share/artex/local.env
psql "$ARTEX_PG_DSN"
```

確認:

```bash
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(8787|8788) '   # 全て 127.0.0.1
nc -z 127.0.0.1 5432; echo $?                          # 1 (Postgres は TCP を開けない)
psql -h ~/.local/share/artex/run -U artex -d artex -c 'select 1'   # password を求められる
tailscale serve status                                 # No serve config
```

復旧 (password 紛失・pg_hba 切替失敗で ARTEX が DB に繋がらない):

1. `launchctl bootout gui/$(id -u)/dev.egahika.artex-postgres` で止め、`~/.local/share/artex/pg/pg_hba.conf` を `local all all trust` に書き換えて `postgres -D ~/.local/share/artex/pg -k ~/.local/share/artex/run -c listen_addresses=` を手で起動する。
2. `openssl rand -hex 32` で新 password を作り、`psql -h ~/.local/share/artex/run -U artex -d postgres -c "ALTER USER artex PASSWORD '<pw>'"` を実行、`local.env` の `ARTEX_PG_DSN` を書き換える (直前の版は `local.env.bak`)。
3. 手起動の postgres を止めて `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.egahika.artex-postgres.plist` で戻す。wrapper が pg_hba を scram-sha-256 に修復する。`launchctl kickstart -k gui/$(id -u)/dev.egahika.artex` で ARTEX を再起動し、`artex.log` に `listening on 127.0.0.1:8787` が出ることを確認する。

## 4. トラブルシュート

### 共有 skill の名前衝突

`nix run .#skills-audit` は `~/.agents/skills` を Pi の loader で読み、採用された skill と diagnostics を JSON で返す。diagnostics がある場合は終了コード 1。別のディレクトリは `nix run .#skills-audit -- /path/to/skills` で指定する。Pi の個人設定やプロジェクト設定は読み込まないため、対象外の探索先を含む起動時 diagnostics は別途確認する。

`~/.agents/skills` は 1 階層だけにする。Pi と Codex は配下を再帰探索するため、`synced/<bucket>/` のような第二の skill root を置くと、同名 skill が毎回 collision になる。claude.ai の skill 同期は `~/.claude/settings.json` の `syncClaudeAiSkills: false` で無効化してあり（user settings は repo 管理外なので再生成されたら再設定する）、同期 skill は `~/.agents/skills` へ実体で持つ。以前の正本 `~/.claude/skills/synced/<bucket>/` は無効化時に `.trash` へ退避される。同期を戻す場合は再ダウンロード後に実体を置き直す。

衝突したら `collision.winnerPath` と `collision.loserPath` を確認し、負けた側の nested な複製を `~/.agents/skills/.trash/<timestamp>/` へ退避する。削除はしない。Pi は dot directory を探索しない。同じ実体への symlink は重複として数えない。退避後に監査を再実行し、diagnostics が空で、期待する `skills[].filePath` が選ばれたことを確認する。復旧時は退避先から元のパスへ戻す。

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

`~/.gitconfig` の credential.helper が削除済み package manager の path に hardcode された旧症状 (PR #15 で修正済)。再発したら:

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

interactive shell では `modules/programs/harness/opencode/preflight.sh` が `opencode` / `opencode2` を包み、起動前に「`service.json` の pid は死んでいるのに port は LISTEN」の不一致を検出して orphan を落とし `service restart` するため、通常は手当て不要。同じ script を `~/.local/bin/opencode-health` として実行でき、launchd (`dev.egahika.opencode-service-health`) が毎日 09:05 に叩き、結果を `~/.cache/opencode-service-health.{log,err}` に残す。orphan が SIGTERM を無視した場合は SIGKILL に escalate し、それでも port が空かなければ TUI を起動せずエラーを返す。以下は preflight を無効化している場合や、PATH に `~/.local/bin` が無い script から `opencode run` を直接叩く場合の復旧手順。

```bash
lsof -nP -iTCP:49374 | grep LISTEN        # 掴んでいる pid を特定
kill <pid>                                # orphan を落とす
opencode service restart && opencode service status
```

判定: `~/.local/share/opencode/log/opencode.log` に `Managed service port 49374 ... already in use` が連続していたらこれ。`opencode service status` が `stopped` でも port が埋まっていれば orphan 確定。

upstream (`sst/opencode`) への issue は当面立てない。preflight が interactive の主経路を自己修復し、上流の恒久修正 (stale `service.json` を検知して orphan を落とす) は調査コストが大きいため。再発が続くか非 interactive 経路で実害が出たら起票する。

### 4.6 secret を rotate する

`~/.config/secrets/env.age` は age で暗号化した `KEY=value` 行、`~/.config/secrets/age-se.txt` が復号鍵の参照 (0600)。鍵本体はこの Mac の Secure Enclave にあり (`age-plugin-se`, access control `none`)、file を複製しても他の機械では復号できない。これが secret の唯一の正史で、シェル起動時には復号しない。読むのは `.envrc` の `use secrets` だけ (§2.6)。同じディレクトリの `.env.keys` / `.env` (dotenvx 由来) は読む実装が無い。未使用なので削除してよい。

```bash
cd ~/.config/secrets
plain=$(mktemp)
trap 'rm -f "$plain"' EXIT
age -d -i age-se.txt env.age >"$plain"
$EDITOR "$plain"
age -e -R <(age-plugin-se recipients -i age-se.txt) -o env.age "$plain"
```

Mac を乗り換えたら新しい機械で `age-plugin-se keygen --access-control none -o age-se.txt` を作り、旧機械で復号した平文を新 recipient で暗号化し直す。SE の鍵は backup できないので、平文の退避先は 1Password 等の別系統にする。

rotate 後は secret を使う repo で `direnv reload` する。direnv は `.envrc` の変更しか検知しないため、env.age の変更は手動 reload まで反映されない。

Bitwarden CLI の unlock は別系統。`bw-touchid-enroll` が `--access-control any-biometry` の SE 鍵 `bw-se.txt` を作り、マスターパスワードを `bw-master.age` に暗号化する。`bwu` は Touch ID で復号して `bw unlock` に渡し、`BW_SESSION` を現在のシェルに export する。マスターパスワードを変えたら enroll し直す。

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

`modules/darwin/nix-store.plist` は macOS の `security` と `diskutil` で System Keychain の既存鍵を渡す。鍵を画面やファイルへ出力しない。UUID を service 名とする鍵を先に探し、Determinate installer 由来の `Nix Store` 名の鍵を fallback とする。`/Volumes/Nix Store` など別の場所に自動マウントされた場合も、`StartOnMount` で検知して unmount し `/nix` に付け直す。

サービスが欠落して Nix を起動できない場合は、リポジトリから復旧する:

```bash
sudo install -o root -g wheel -m 644 ~/dotfiles/modules/darwin/nix-store.plist /Library/LaunchDaemons/org.nixos.darwin-store.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.darwin-store.plist
nix store info
nix run ~/dotfiles#switch
```

plist は `/nix` のマウント前に読める実ファイルとして nix-darwin activation が配置する。Determinate の実行ファイルやサービスは復元しない。再起動後に `mount` と `nix store info` を再確認する。

### 4.8 gh extension が起動しない

`gh extension list` に出るのに実行が `no such file or directory` で失敗する場合、`~/.local/share/gh/extensions/gh-<name>` が消えた clone を指す dangling symlink か、directory はあるのに実行ファイル `gh-<name>` が無い状態になっている。`nix run ~/dotfiles#audit` は ledger の後に全 extension を検証し、`DANGLING` (symlink 先が無い) / `BROKEN` (実行ファイルが無い、または実行不可) を報告して終了コード 1 で止まる。

`gh extension install` は既存 entry があると修復せず拒否するため、どちらの復旧も dangling entry を先に消す。

```bash
nix run ~/dotfiles#audit
rm ~/.local/share/gh/extensions/gh-<name>
gh extension install <owner>/gh-<name>            # 配布版に戻す
```

ローカル開発中の extension (symlink 型) は clone を戻してから symlink を張り直す。ローカル install は clone 内で `.` を指定した時だけ symlink を作る。

```bash
rm ~/.local/share/gh/extensions/gh-<name>
ghq get <owner>/gh-<name>
(cd ~/ghq/github.com/<owner>/gh-<name> && gh extension install .)
nix run ~/dotfiles#audit
```

symlink 型の clone は `ghq-clean.py` が `gh extension target` として保護する (7.4)。

### 4.9 AWS の SSO session を張り直す / broker が応答しない

`default` / `hikae-admin-sso` と role chain の profile は `credential_process` で `~/.local/bin/aws-cred-client` を呼び、`~/.cache/aws-cred/agent.sock` の常駐 broker (`dev.egahika.aws-cred-agent`) が host 側で `aws configure export-credentials` を実行して短寿命 credential だけを返す。SSO token store (`~/.aws/sso`, `~/.aws/cli`) は broker しか読まず、sandbox からは deny される。設計は `docs/solutions/secrets/aws-credential-broker.md`。

```bash
aws sso login --sso-session hikae                            # sandbox 外の端末で実行 (90 日毎)。profile 名ではなく session 名を渡す
aws sts get-caller-identity --profile default                # broker 経由で復帰を確認。再起動は不要
launchctl print gui/$(id -u)/dev.egahika.aws-cred-agent      # broker の state
launchctl kickstart -k gui/$(id -u)/dev.egahika.aws-cred-agent
tail -n20 ~/Library/Logs/aws-cred-agent.log
~/.local/bin/aws-cred-client sso-readonly | jq .Expiration   # broker 単体の疎通。allowlist 外の profile 名は exit 1
```

sandbox 内の `aws sso login` は cache に書けず失敗する。これは仕様で、login は常に sandbox 外で行う。broker の allowlist (`sso-readonly` / `sso-admin` / `*-chain`) を増減するときは `modules/programs/aws.nix` の `sourceProfiles` と `tests/aws-cred-broker.sh` を同時に更新する。

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

# 3) switch が Aqua link と native app bootstrap まで適用する
```

## 7. 容量

ディスクは 229G の APFS コンテナ。2026-10-25 の棚卸しで 212G 使用 (空き 17G) だったものを、下記で空き 60G 超まで戻した。再び詰まったら ladder が `report_candidates` で候補を出す。

| 回収経路                            | 対象                                                                                                                                                                                                 | 2026-10-25 の回収量                       |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| ladder (6h 毎、空き 10% 未満で発火) | nix GC (世代込み) / 再取得できる cache (artex `import/` の 30 日超を含む) / Codex 旧 release / artex deploy 世代 (新しい 2 つ以外) / ゴミ箱 / podman の未使用 image・container と 30 日起動の無い VM | 数百 MB〜数 GB                            |
| tombstone (毎回、空き率に関係なく)  | 退役 tool の state: `~/go`, `~/Library/pnpm`, mise。sandbox fallback の `~/ghq/**/.pnpm-store`                                                                                                       | 20G                                       |
| 手動 / `--podman-machine NAME`      | 停止済み VM、project 毎の provider 複製                                                                                                                                                              | 17G                                       |
| `--archive PATH`                    | 唯一のコピーだが手元に要らないもの (Codex 作業 dir、旧 workspace)                                                                                                                                    | 13G (S3 へ)                               |
| OS (sudo)                           | 適用待ち macOS 更新 (Preboot `cryptex1/proposed`) + Chrome `code_sign_clone`                                                                                                                         | 25G (2026-10-25 適用済み、再発防止は 7.1) |

artex の `pg/` と `~/.local/share/containers` (podman machine の VM disk) は消さない。代わりに `sizes.tsv` に `日付<TAB>artex<TAB>containers<TAB>Documents/Codex` (KiB) を 7 日毎に追記し、前回記録より増えた項目を毎回の log に `増加:` として出す。VM disk の回収は `--podman-machine NAME` のまま。

`disk-maintenance.sh` の nix 段は `nix-collect-garbage --delete-older-than 30d` 1 本で、`~/.local/state/nix/profiles/*` (home-manager / profile / channels) の古い generation を消してから未参照 path を回収する。

過去にはこのコマンドが `--dry-run` でも CloudStorage 配下の `proc` で `Resource deadlock avoided` (EDEADLK)、別の実行では `~/Library/Application Support/AddressBook` の `Operation not permitted` (EPERM) で終了したため、`nix-env --delete-generations` + `nix store gc` の 2 段に分けていた。2026-11-03 に Nix 2.34.9 で `--dry-run` と実 GC (13375 path, 362.5 MiB) の両方が同じ profile 構成で成功したので 1 本に戻した。再発したら 2 段に戻し、失敗した path をここに追記する。

### 7.1 macOS 更新の月次適用 (sudo が要る、ladder の対象外)

Preboot と `/System/Volumes/Update` が膨らむのは download 済みで適用していない更新が積まれているため。放置すると 20G 前後が常時占有され、版が進むたびに再 download される。

運用は「download は自動、install は月初の手動 window」に固定する。`AutomaticallyInstallMacOSUpdates` は採用しない。夜間の自動再起動は artex / ghtkn-agent / ssh-agent など常駐 agent を無警告で落とし、ghtkn の再認証 (`ghauth`) と artex の再起動確認が翌朝まで遅れるため。設定は `modules/darwin/system.nix` (§3.5)。

月初の window で次を行う。ladder の `report_candidates` が Preboot の staged サイズを出していれば、それが適用待ちの合図。

```sh
softwareupdate --list                       # 適用待ちの一覧 (minor を優先、major は別途判断)
tmutil listlocalsnapshots /                 # com.apple.os.update-* が staged 更新の実体
sudo softwareupdate --install '<Label>' --restart   # 例: 'macOS Tahoe 26.7.2-25G332'
```

再起動後は `nix run ~/dotfiles#launchd-audit` と `ghauth` で常駐 agent と認証を戻す。スナップショットを先に消すと staged 更新が壊れるので、必ず適用を先に済ませる。major (27.x) は minor と同じ手順で適用できるが、nix-darwin と Nix installer の対応を確認してから行う。

### 7.2 S3 への退避 (`--archive`)

bucket は `hikae-archive-951872725222` (iac-aws `projects/other/archive.tf`)。CLI の default profile (ReadOnlyAccess) に `PutObject` 系だけ bucket policy で足してあり、削除は `hikae-admin-sso` でしかできない。object は GLACIER_IR (即時取得、$4/TB/月)、key は `<hostname>/<HOME からの相対 path>`、directory は `.tar.zst` に固めて置く。

```sh
aws sso login --sso-session hikae                                  # 90 日毎 (4.9)
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

`disk-maintenance.sh --dry-run` は空き率が目標以上でも、`Documents/Codex/YYYY-MM-DD` のうち30日より古いものを archive 候補として表示する。自動退避・削除はしない。`~/ghq/**/packages/*/.local` (HOME を package dir に差し替えた検証の残骸) は目標未達時の候補に出すだけで、削除は repo 側の gitignore / clean 手順に任せる。`~/ghq` 配下の `.pnpm-store` は store の再 fetch で戻るので tombstone として毎回消す。`modules/programs/harness/ai-sandbox.nix` は `$HOME` を writable に含めるため `~/.local/share/pnpm` はその範囲内で、fallback が起きる実行時原因は未確認。

### 7.4 ghq clone / branch の棚卸し

`ghq-clean.py` は `~/ghq/github.com/<owner>/<repo>` 直下の `.git` directory を clone root として扱い、linked worktree (`.git` file) は既存 `clean-worktree.sh` の管理対象として数を分けて表示する。候補は remote が archived、または最新 local ref commit と GitHub `pushedAt` の新しい方が既定14日以上前の clone。dirty な clone と linked worktree を持つ clone は保護する。`~/.local/share/gh/extensions` の symlink が指す clone も保護する (ローカル開発中の gh extension は binary を repo 内に持つため、clone を消すと extension が起動しなくなる)。gh extension directory を読めない場合は全 clone を `unknown` として削除候補にしない。remote ref から到達できない commit (local-only commit) を持つ clone と upstream の無い branch を持つ clone も既定で保護し、理由に `local_only_commits=N` / `upstreamless_branches=N` を出す。push していない作業を含めて候補にしたい時だけ `--allow-unpushed` を付ける。

remote metadata は最大25 repository slugを1 GraphQL requestにまとめ、owner-onlyの `~/.cache/ghq-clean/metadata.json` に24時間 cache する。失敗時は同じ期間 API を再試行せず、cache が無い/古い/取得失敗なら `unknown` として削除候補にしない。GraphQL の null は deleted と権限不足の private repository を区別できないため、どちらも `unknown` にする。

定期実行は `disk-maintenance.sh` から `--dry-run` を呼ぶだけで、clone を削除しない。手動削除は候補一覧を確認してから対話端末で実行する。

```sh
~/dotfiles/scripts/ghq-clean.py --dry-run
~/dotfiles/scripts/ghq-clean.py --apply
~/dotfiles/scripts/ghq-clean.py --apply --allow-unpushed
```

`--apply` は実行直前に対象 remote metadata、local HEAD/ref OID、dirty/worktree 状態を再検証し、候補数の確認入力を要求する。bundle / backup は作らず、削除した local-only commit 数を結果に記録する。

gh extension の symlink が dangling になった時の復旧は 4.8。
