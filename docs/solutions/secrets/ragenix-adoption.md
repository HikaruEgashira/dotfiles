# ragenix は採用しない

## 決定

secrets 管理に ragenix を導入しない。編集用途で必要になった場合のみ `pkgs.ragenix` を使い、flake input には足さない。

## 根拠

1. **得るものが CLI だけ。** nix-darwin を採用したので agenix 系モジュールは動くが、ragenix が足すのは edit / rekey の対話 CLI で、`docs/operations.md` の age 2 行を置き換える程度。activation 時に `/run/secrets` へ展開するモデル自体は下の 2 と衝突する。
2. **移行先と逆行する。** `docs/ideation/2026-05-02-secure-fast-lean-dotfiles-ideation.md` #3 は起動時グローバル復号の廃止と direnv への局所化を計画している。ragenix は activation 時グローバル配布モデルで、廃止対象と同じ側にある。
3. **上流が遅い。** 最終 commit は 2025-10-30、2025 年内の commit は 2 件、GitHub release なし、open issue 21、実質 1 名。同時期の agenix は 2026-10-20、sops-nix は 2026-10-24 に commit。security 隣接のツールで最も動きの遅い選択肢を選ぶ理由がない。
4. **closure が重い。** nixpkgs の ragenix は 2025.03.09 で cache.nixos.org に署名済み (narinfo 200 確認)、ローカル build 規則には触れない。ただし `secrets.nix` の eval に nix 本体を参照する。

## 代替

secret を宣言管理するなら sops-nix を先に評価する。home-manager モジュールを直接持ち、上流が活発。ragenix / agenix の再評価条件は「age 鍵を Secure Enclave / 1Password の外に出さずに activation 配布したくなったとき」。
