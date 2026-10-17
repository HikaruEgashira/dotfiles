# Playbooks

「どの手順をいつ使うか」を列挙する索引。手順本文は重複を避けて各ドキュメントに置く。

## 日常

| Playbook       | 使う時                                    | 手順                                        |
| -------------- | ----------------------------------------- | ------------------------------------------- |
| 設定を反映     | module / package / ledger を変更したら    | `docs/operations.md` §1 日常運用            |
| 棚卸し         | ledger か launchd の drift が気になったら | `docs/operations.md` §1 / `docs/launchd.md` |
| 静的検査・整形 | commit 前                                 | `docs/operations.md` §1 日常運用            |
| inputs 更新    | 週次の自動更新を待てない時                | `docs/operations.md` §1 日常運用            |

## 追加

| Playbook          | 使う時                         | 手順                      |
| ----------------- | ------------------------------ | ------------------------- |
| package を足す    | `pkgs.<name>` で済む CLI / GUI | `docs/operations.md` §2.1 |
| program を足す    | 設定ファイルが要る             | `docs/operations.md` §2.2 |
| host を足す       | 2 台目以降                     | `docs/operations.md` §2.3 |
| XDG 移設を足す    | dotdir を XDG へ寄せる         | `docs/operations.md` §2.4 |
| Brewfile に逃がす | nixpkgs broken / kext / cask   | `docs/operations.md` §2.5 |

## オプトイン有効化

| Playbook             | 使う時                 | 手順                      |
| -------------------- | ---------------------- | ------------------------- |
| Firewall posture     | 新マシン / 遮断を戻す  | `docs/operations.md` §3.0 |
| sudo Touch ID        | 新マシン / 解除        | `docs/operations.md` §3.1 |
| cachix substituter   | 新マシン / 撤回        | `docs/operations.md` §3.2 |
| Encrypted DNS        | 新マシン / 回線変更    | `docs/operations.md` §3.3 |
| 署名鍵ローテーション | 鍵を替える / 端末追加  | `docs/operations.md` §3.4 |
| 自動アップデート固定 | 新マシン (要 sudo)     | `docs/operations.md` §3.5 |
| self-hosted runner   | 新マシン / runner 停止 | `docs/operations.md` §3.6 |

## 復旧

| Playbook           | 使う時                     | 手順                      |
| ------------------ | -------------------------- | ------------------------- |
| activation 失敗    | eval が通らない / 反映不能 | `docs/operations.md` §4.1 |
| CI 失敗            | PR の check が赤           | `docs/operations.md` §4.2 |
| `git push` 不能    | `Device not configured`    | `docs/operations.md` §4.3 |
| dotfiles-sync 停止 | 日次同期が来ない           | `docs/operations.md` §4.4 |
| HM ロールバック    | 直近適用を戻したい         | `docs/operations.md` §5.1 |
| main revert        | 悪い commit を戻したい     | `docs/operations.md` §5.2 |
| cachix trust 撤回  | substituter を止めたい     | `docs/operations.md` §5.3 |
| 新マシン bootstrap | マシンを追加               | `docs/operations.md` §6   |

## 記載ルール

- 手順は 1 箇所にだけ書く。索引はリンクのみで、コマンドを複製しない。
- 使い捨ての調査ログや dated な audit は `docs/ideation/` (gitignore) に置き、ここには載せない。
