# nix-darwin を採用し、Nix は upstream に戻す

## 決定

マシン層 (`/etc`, `defaults`, sudo/PAM, ALF, launchd, Homebrew) は nix-darwin が宣言管理する。Nix daemon と `/etc/nix/nix.conf` も nix-darwin の所有とし、Determinate Nix は使わない。ユーザー層は home-manager のまま `home-manager.users.hikae` として同じ flake から評価する。

## 構成

- 入口は `hosts/macbook-air/default.nix`、実装は `modules/darwin/*`。2 台目はホスト module を足して `darwinConfigurations` に追加する。
- 適用は `nix run .#switch` (= `sudo darwin-rebuild switch --flake .#hikae`)。root が要るため 09:00 の `dotfiles-sync` は build 検証と `pending` 記録までに留める。
- Homebrew は `modules/darwin/homebrew.nix` が Brewfile を生成し、activation で `sudo --user=hikae brew bundle` を実行する。
- firewall は `networking.applicationFirewall` で設定し、activation 末尾で `socketfilterfw` の実効値を読み戻して失敗させる。

## 根拠

1. **sudo 層が宣言化される。** 従来は firewall 用の NOPASSWD、Touch ID の PAM、Wi-Fi の静的 DNS 掃除を activation script と手書き sudoers で持っていた。nix-darwin では全て設定ファイルに落ちる。
2. **`/etc` の所有権が一意になる。** home-manager だけでは `/etc` を触れず、手順書と実体が乖離していた。
3. **Determinate を外す理由。** nix-darwin は `nix.*` を管理するとき `/etc/nix/nix.conf` と `org.nixos.nix-daemon` を所有する。Determinate は `systems.determinate.*` で同じ領域を管理し、`nix.conf` を再生成する。二重管理を避けるため、daemon・`nix.conf`・launchd を nix-darwin に一本化した。

## 運用上の依存

- 暗号化された `/nix` は `org.nixos.darwin-store` が System Keychain の既存鍵で解除・マウントする。`fstab` だけでは解除できない。plist は起動前に読める実ファイルとして nix-darwin activation が配置する (`docs/operations.md` §4.7)。
- `nix.enable = true` のため `nix-darwin` は `/usr/local/bin/determinate-nixd` が存在すると activation を拒否する。Determinate 由来の痕跡は残さない。
- 世代のロールバックは `sudo darwin-rebuild --rollback`。home-manager 単体の generation は nix-darwin 経由で間接的にしか使わない。

## 代替

- Determinate Nix を維持する場合は `nix.enable = false` が必要で、`nix.settings` / nix-daemon 管理を失う。
- secrets は nix-darwin 採用で activation フックが使えるようになったため、`docs/solutions/secrets/ragenix-adoption.md` の判断を sops-nix 中心に更新した。
