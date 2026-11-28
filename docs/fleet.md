# Fleet による端末管理

Fleet server は他から分離した AWS アカウント `device-fleet` に置く (構築前)。ms-a2 には置かない。設計と理由は `docs/security/threat-model.md` §5。dotfiles 側の部品は配布の仕組みとして残してある: CI の `promote` job が CI 緑の main を、HikaruEgashira が GitHub environment `deploy` で approve した後にだけ `deploy` branch へ fast-forward し (`deploy` branch は iac-github の ruleset で deploy key 以外の更新を拒否する。deploy key の秘密鍵は AWS Secrets Manager `dotfiles/deploy-key` にあり、promote job が sub を `environment:deploy` に固定した OIDC role `dotfiles-deploy` で取得する)、`scripts/fleet-controller.py` が `deploy` を読んで `scripts/fleet/dotfiles-apply.sh` を Fleet 経由で各 Mac に root で流す。

## 端末の登録

server 構築後に使う。URL と secret 名は iac-aws `projects/device-fleet` の output が正。

1. Mac: Fleet UI > Hosts > Add hosts > macOS で fleetd の `.pkg` を作り、各 Mac で開く。enroll secret は Secrets Manager にあり、repo と端末に置かない。登録後、Hosts に表示され policy `dotfiles: applied approved deploy` が評価されることを確認する。
2. Android Enterprise の紐付け (1 回だけ、本人の Google アカウントが要る): Fleet UI > Settings > Integrations > Mobile device management > Android > Connect で Google にログインし enterprise を作る。Google からの通知を受ける Android 用 path だけが公開され、管理 UI/API は tailnet 内に限る。
3. Android 端末 (`poco-f7-ultra`): Fleet UI > Hosts > Add hosts > Android の登録リンクを端末で開き、仕事用プロファイルを作る。個人領域は管理対象外。Hosts に表示されることを確認する。
4. 登録解除: Mac は Fleet UI から host を削除して fleetd を uninstall する。Android は端末の 設定 > アカウント から仕事用プロファイルを削除する。
