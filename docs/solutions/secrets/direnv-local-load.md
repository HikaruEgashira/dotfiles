# secret は direnv で repo 局所にロードする

## 決定

1. secret の正史は `~/.config/secrets/env.age` 1 本。`.env.keys` / `.env` は読む実装を持たず、正史から外す。
2. zsh 起動時の全キー復号・export (`_SECRETS_GEN` ブロック) を廃止する。
3. 代わりに direnv の stdlib 拡張 `use_secrets [KEY...]` を home-manager で宣言し、secret が要る repo の `.envrc` に `use secrets <KEY>` を書く。無指定なら全キーだが、原則キー名を列挙する。

## 根拠

1. **継承範囲が広すぎた。** 起動時 export は、その後に起動する全プロセス (tmux / herdr / sandbox 内の AI agent を含む) に全 secret を渡していた。sandbox は `~/.config/secrets` の読み取りを deny するが、環境変数は deny の外側で親から継承されるため、ファイル保護が意味を持たなかった。
2. **必要なキーは repo ごとに 1〜2 個。** `use secrets KEY` で宣言すれば、渡る範囲はそのディレクトリ配下のシェルと子プロセスに限られ、何を渡したかが `.envrc` に残る。
3. **`_SECRETS_GEN` の運用負債を消せる。** キーを増減するたびに世代番号を上げる手順と、上げ忘れで古い環境が永続する障害モードが無くなる。direnv は `.envrc` 単位で毎回評価する。
4. **正史を 1 本にする。** dotenvx 由来の `.env.keys` / `.env` は何も読んでいなかった。読む側が無いファイルを正史に含めると rotate 手順が二重になる。

## 不採用

- agenix / ragenix / sops-nix: activation 時にグローバル配布するモデルで、局所化と逆行する。詳細は `ragenix-adoption.md`。
- 1Password 等への age 鍵の移管: 鍵の取得経路が対話認証を伴い、本決定と独立に評価できるため分離した。

## 影響

- 新しい zsh には secret が無い。`direnv exec <repo> <cmd>` か、その repo に `cd` して使う。
- env.age を rotate したら、使っている repo で `direnv reload` する。
