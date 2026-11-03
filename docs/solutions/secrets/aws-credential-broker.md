# AWS credential は unix socket broker 経由で sandbox に渡す

## 決定

claude / codex の sandbox には `~/.aws/config` だけを読ませ、`~/.aws/sso` `~/.aws/cli` `~/.aws/credentials` `~/.aws/login` は read / write とも deny する。sandbox で使う profile は `credential_process = ~/.local/bin/aws-cred-client <source-profile>` とし、client は `~/.cache/aws-cred/agent.sock` の常駐 broker (`dev.egahika.aws-cred-agent`, `modules/programs/aws/broker.py`) に profile 名を 1 行送る。broker は allowlist (`sso-readonly` / `sso-admin` / `seccamp-src` と `*-chain` 3 つ) 内だけ host の `aws configure export-credentials --format process` を実行し、出力をそのまま返す。role chain (`iac-aws-apply`, `artex-microvm`, `seccamp-lab-apply`) も host 側の `*-chain` profile が `sso-admin` を source に assume し、sandbox には結果の STS credential だけが渡る。

## 根拠

1. **SSO token が平文で sandbox に見えていた。** `~/.aws/cli/cache/session.db` は AWS CLI v2 の SSO access / refresh token を平文で持つ SQLite で、sandbox の任意コードが読むと SSO portal から任意の割当 role の credential を再発行できる。ghtkn の暗号化 token store と同じクラスの経路で、AWS 側は暗号化すらされていない。
2. **`~/.aws` 全体を deny すると sandbox で AWS が使えない。** profile 解決に config が要り、deny すると AWS 利用を sandbox 外へ出すしかなくなる。設定は読める / 秘密 cache だけ deny / credential は socket、の三段構えにすると sandbox 内実行を維持できる。
3. **SSO と `credential_process` は同じ profile に置けない。** 同居させると SSO が優先され `credential_process` が無視される (`Error loading SSO Token`)。host 専用の source profile と sandbox 用 profile を分ける必要がある。
4. **broker は credential を保持しない。** 要求ごとに host の CLI を叩き、CLI 側の SSO cache と assume-role cache が TTL を管理する。passphrase unlock や lock 機構を持たず、SSO session の expiry がそのまま gate になる。
5. **sandbox の CLI は assume-role できない。** botocore は assume-role の結果を `~/.aws/cli/cache/<hash>.json` に書き、書けないと `Operation not permitted` で失敗する (2026-11-03 に claude sandbox で確認)。`~/.aws/cli` を deny する以上、chain は host 側で解決するしかない。
6. **依存を増やさない。** `pkgs.python3` は ledger 済みで、socket server と client を 1 ファイルに同居させられる。`socat` + shell は package 追加と error 伝播の弱さ、`aws-sso-cli` / `aws-vault` / `granted` は socket 以外の取得経路 (HTTP localhost / keychain / encrypted cache) が残るため採用しない。

## 信頼境界

- socket は同一 uid の任意プロセスが接続できる。ghtkn socket と同じ前提で、sandbox 内 malware の被害は「短寿命 credential の取得」に限定され、SSO token の持ち出しはできない。
- `sso-admin` (AdministratorAccess) を allowlist に残しているため、sandbox から取れる最大権限は従来と変わらない。絞る場合は allowlist から外し、apply を sandbox 外へ移す。
- broker が実行する profile の `source_profile` は host 専用 (`sso-admin` / `seccamp-lab-org`) のみで、broker client を source にして socket を再帰させない。`tests/aws-cred-broker.sh` がこれと `export-credentials` wrapper の再登場を弾く。

## 運用

- login: `aws sso login --sso-session hikae` を sandbox 外で実行する。`docs/operations.md` §4.8。
- 復旧: Phase 3 相当の deny (`modules/programs/harness/ai-sandbox.nix` の `.aws/*` 4 path と codex の `"${home}/.aws" = "read"`) を戻せば、broker を残したまま従来動作に戻る。
- 固定: `tests/ai-sandbox-deny-lists.sh` が deny path と socket allowlist、`tests/aws-cred-broker.sh` が allowlist の拒否と失敗伝播、`nix run .#launchd-audit` が agent label を検査する。
