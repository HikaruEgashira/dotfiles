# dotfiles

## ビルド・適用

```bash
# PATHにnixがない環境では先頭にexportが必要
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

# home-managerの適用
nix run home-manager -- -f ~/dotfiles/home.nix switch
```

## 構成

- `home.nix` - エントリポイント
- `modules/programs/` - プログラムごとの設定 (git等)
- `modules/settings/zsh-config.nix` - zshのalias, PATH, secrets

## シェルエイリアスの追加

`modules/settings/zsh-config.nix` の `aliases` ブロックに追記する。
