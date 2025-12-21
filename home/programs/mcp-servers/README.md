# MCP Servers Configuration

Claude Code用のMCP（Model Context Protocol）サーバー設定ファイル。

## ファイル構成

- `flake.nix` - Nix Flakesベースの統合設定（推奨）
- `claude-code-config.nix` - 従来の方法での設定（代替）

## セットアップ

### 1. 暗号化ファイルの初期化

```bash
# ~/.config/secrets/.env を作成
mkdir -p ~/.config/secrets
cat > ~/.config/secrets/.env << EOF
TAVILY_API_KEY=tvly-...
OPENMEMORY_API_KEY=om-...
CEREBRAS_API_KEY=csk-...
OPENAI_API_KEY=sk-...
EOF

# dotenvxで暗号化
cd ~/.config/secrets
dotenvx encrypt .env
chmod 600 .env.keys
```

### 2. home-managerに統合

`home.nix`でモジュールを有効化：

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./programs/mcp-servers.nix
  ];

  programs.mcp-servers.enable = true;
}
```

### 3. Claude Codeに統合

#### 方法1: Flakes（推奨）

```bash
# リポジトリの flake.nix をホームディレクトリにリンク
ln -sf ~/dotfiles/home/programs/mcp-servers/flake.nix ~/flake.nix

# Claude Codeの設定
nix flake update
```

#### 方法2: Static config

```bash
# claude-code-config.nixを生成
nix eval --raw "$(cat ~/dotfiles/home/programs/mcp-servers/claude-code-config.nix)" > ~/.claude/mcp.json
```

## セキュリティ

- ✅ API キーは**暗号化**されて保存
- ✅ 復号化キーは**git-ignored**
- ✅ 実行時のみ**メモリに展開**
- ✅ ファイルパーミッション：`600`

## トラブルシューティング

### API キーが読み込まれない

```bash
# dotenvxの復号化をテスト
cd ~/.config/secrets
export DOTENV_PRIVATE_KEY=$(sed -n 's/^DOTENV_PRIVATE_KEY=//p' .env.keys)
dotenvx run -- printenv | grep -E "TAVILY|OPENMEMORY|CEREBRAS"
```

### home-managerが失敗する

```bash
# home-manager再実行
home-manager switch -b backup
```

## 参照

- [dotenvx Documentation](https://dotenvx.com)
- [natsukium/mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix)
- [Anthropic MCP](https://modelcontextprotocol.io)
