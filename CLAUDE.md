# dotfiles

## ビルド・適用

```bash
# PATHにnixがない環境では先頭にexportが必要
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

# home-managerの適用
home-manager switch --flake ~/dotfiles
```

## 構成

- `home.nix` - エントリポイント
- `modules/programs/` - プログラムごとの設定 (git等)
- `modules/settings/zsh-config.nix` - zshのalias, PATH, secrets

## シェルエイリアスの追加

`modules/programs/zsh.nix` の `shellAliases` に追記する。
