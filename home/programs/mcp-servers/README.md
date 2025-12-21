# MCP Servers Configuration

MCP（Model Context Protocol）サーバーのNix設定ファイル。

複数のMCPサーバー（Tavily、OpenMemory、Cerebras等）を統合管理します。

## ファイル構成

- `flake.nix` - Nix Flakesベースの統合設定（推奨）
- `claude-code-config.nix` - Claude Code用の静的設定（代替）
- `mcp-servers.nix` - home-managerモジュール

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

### 3. Claude Code用の設定

Claude Codeで使用する場合：

```bash
# 方法1: flake.nixをホームディレクトリにリンク（推奨）
ln -sf ~/dotfiles/home/programs/mcp-servers/flake.nix ~/flake.nix
nix flake update

# 方法2: claude-code-config.nixから設定を生成
nix eval --raw "$(cat ~/dotfiles/home/programs/mcp-servers/claude-code-config.nix)" > ~/.claude/mcp.json
```

### 4. その他のアプリケーション用

`flake.nix`はClaude Code以外のアプリケーション（Claude Desktop等）でも使用可能です。
各アプリケーションのMCP設定で参照してください。

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

- [Model Context Protocol (MCP)](https://modelcontextprotocol.io)
- [dotenvx - Secrets Management](https://dotenvx.com)
- [natsukium/mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix)
- [Anthropic Claude](https://www.anthropic.com)
