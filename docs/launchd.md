# launchd Inventory

macOS の launchd に常駐するジョブの棚卸し。目的は「宣言管理 (home-manager) / 外部ツール自己管理 / vendor 常駐 / 死骸」を一覧で区別し、後から増えた野良ジョブを検知できるようにすること。操作手順は `operations.md`、設計理由は `../AGENTS.md` と各 module を参照。

## 再生成コマンド

```bash
launchctl list | awk 'NR>1 {print $0}'                 # user domain (gui/<uid>)
ls ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons
nix run ~/dotfiles#launchd-audit                        # 野良 agent の検知
```

`launchctl list` は user domain のみ。system daemon は `sudo launchctl print system/<label>` で個別に確認する。

## user domain (`~/Library/LaunchAgents`)

| Label                           | 管理                                                 | 起動         | 備考                          |
| ------------------------------- | ---------------------------------------------------- | ------------ | ----------------------------- |
| `dev.egahika.dotfiles-sync`     | home-manager (`modules/programs/dotfiles-sync.nix`)  | 毎日 09:00   | main 追従 + 再 activation     |
| `dev.egahika.clean-worktree`    | home-manager (`modules/programs/clean-worktree.nix`) | 毎週月 09:30 | merged worktree 掃除          |
| `com.claude.caffeinate`         | home-manager (`modules/programs/claude.nix`)         | 常駐         | claude 実行中だけ sleep 抑止  |
| `com.atlassian.twg.upkeep`      | **twg 自己管理** (`twg upkeep enable`)               | 12 分間隔    | OAuth refresh + upgrade check |
| `com.opencodex.proxy`           | **opencodex 自己管理** (`ocx service`)               | 常駐         | Codex provider proxy          |
| `com.google.GoogleUpdater.wake` | vendor (GoogleUpdater.app)                           | 1 時間間隔   | Chrome/Google app 更新        |

twg / opencodex は binary が自己更新するため home-manager に持たせない（持たせるとツール更新のたびにパスがずれ、plist を書き戻して綱引きになる）。`nix run .#launchd-audit` の許容リストに含めて drift として扱わない。

GUI アプリが登録する background item は次のとおり（app 側が管理、手動操作対象外）。

| Label                                         | 由来             |
| --------------------------------------------- | ---------------- |
| `com.google.GoogleUpdater.wake`               | Google Chrome    |
| `com.openssh.ssh-agent`                       | macOS 標準       |
| `io.tailscale.ipn.macsys.login-item-helper`   | Tailscale (cask) |
| `com.openai.codex-sparkle-{progress,updater}` | Codex (cask)     |
| `jp.kiok.nani.ShipIt`                         | Nani             |

## system domain (`/Library/LaunchDaemons`)

| Label                                        | 管理                      | 起動      | 備考           |
| -------------------------------------------- | ------------------------- | --------- | -------------- |
| `systems.determinate.nix-daemon`             | determinate-nix installer | socket    | nix daemon     |
| `systems.determinate.nix-store`              | determinate-nix installer | boot      | store init     |
| `systems.determinate.nix-installer.nix-hook` | determinate-nix installer | on-demand | installer 修復 |

nix installer が所有するため手動編集しない。Cloudflare WARP / cloudflared daemon / Tunnelblick は下記「撤去」を参照。

## 撤去 (再出現したら drift)

残骸・重複。`scripts/launchd-cleanup.sh` を通常ユーザで実行して削除する（内部で必要な箇所だけ `sudo` を呼ぶ。冪等）。

| 対象                                                                              | 理由                                                                      | 状態                      |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------- |
| `com.google.keystone.{agent,xpcservice}`                                          | plist が空 dict の死骸。`/Library/Google/GoogleSoftwareUpdate` も空       | スクリプト実行待ち (root) |
| `com.cloudflare.1dot1...warp.daemon` + `com.cloudflare.warp.updater` + login item | WARP を完全削除                                                           | スクリプト実行待ち (root) |
| `com.cloudflare.cloudflared` daemon                                               | token ファイル欠落で起動失敗。CLI は nix (`pkgs.cloudflared`) で足りる    | スクリプト実行待ち (root) |
| `net.tunnelblick.tunnelblick{,.launcher}` + cask                                  | VPN プロファイルが空。`openvpn` は nix 管理                               | スクリプト実行待ち (root) |
| brew `watchman` / `cloudflared`                                                   | nix 重複                                                                  | 削除済み                  |
| watchman agent + `pkgs.watchman`                                                  | 唯一の利用者 pleno-live が dormant。Metro は内蔵 watcher にフォールバック | 削除済み                  |

## 検知

`nix run .#launchd-audit` は user domain の非 Apple agent を許容リストと突き合わせ、未知のラベルを `UNKNOWN` として報告し exit 1 する。新しい常駐を足したら、この表と許容リスト (`flake.nix`) の両方を更新する。
