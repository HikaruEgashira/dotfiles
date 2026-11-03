# env.age の復号鍵を Secure Enclave に置く

## 決定

`~/.config/secrets/env.age` の recipient を x25519 鍵 (`age-key.txt`) から `age-plugin-se` の Secure Enclave 鍵 (`age-se.txt`) に替える。access control は `none`。

## 根拠

1. **鍵の持ち出しを潰す。** x25519 鍵は 0600 の file で、user 権限で読めるものは全て複製できる。SE 鍵は chip から出ず、`age-se.txt` は参照でしかない。この Mac で動く process 以外は env.age を開けない。
2. **access control は `none`。** `any-biometry-or-passcode` は復号毎に Touch ID を求める。`use secrets` は direnv が directory に入る度に走るので、prompt が作業を止める。得たいのは「鍵の非可搬性」であって「操作毎の承認」ではない。ai-sandbox は `~/.config/secrets` を read deny しており、sandbox 内 agent は identity file 自体に触れない。
3. **cache.nixos.org に output がある。** `pkgs.age-plugin-se` 0.2.1 は substitute できる。ローカル build 禁止の規約に触れない。

## 代替と見送り

- 1Password / sops-nix: 別 service / 別 model への依存を増やす。age の CLI 2 行で足りる現状を維持する。
- `passcode` / biometry: direnv の頻度と合わない。必要になれば `age-plugin-se keygen --access-control` で作り直して再暗号化する。

## 運用

- rotate / 編集手順は `docs/operations.md` §4.6。
- SE 鍵は backup できない。機械の乗り換え時は平文を 1Password 等に退避してから新機械で keygen し直す。
- 旧 `age-key.txt` と `env.age.x25519.bak` は移行確認後に削除する。残したままでは「持ち出せる鍵」が残る。
