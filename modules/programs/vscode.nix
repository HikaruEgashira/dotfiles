# VS Code 拡張の declarative 管理 (Survivor #2 phase 2)
#
# 旧体制: Brewfile に `vscode "..."` 行で imperative 同期。
# 新体制: nix-vscode-extensions overlay 経由で nix-store 管理。
#
# 拡張の追加は本ファイルの `extensionIds` に publisher.name を 1 行追加するだけ。
# 削除も同様に行を消すだけで activation 時に extension dir から外れる。
{
  pkgs,
  lib,
  ...
}:

let
  m = pkgs.vscode-marketplace;

  # publisher.name 形式の文字列リスト。Brewfile から移行した 41 件。
  # 名前順にソート (publisher 単位での視認性優先)。
  extensionIds = [
    "anthropic.claude-code"
    "arcticicestudio.nord-visual-studio-code"
    "astral-sh.ty"
    "bierner.markdown-mermaid"
    "biomejs.biome"
    "denoland.vscode-deno"
    "docker.docker"
    "editorconfig.editorconfig"
    "github.copilot-chat"
    "github.vscode-pull-request-github"
    "kilocode.kilo-code"
    "mads-hartmann.bash-ide-vscode"
    "mikestead.dotenv"
    "ms-azuretools.vscode-containers"
    "ms-azuretools.vscode-docker"
    "ms-ceintl.vscode-language-pack-ja"
    "ms-python.debugpy"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.vscode-python-envs"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
    "ms-vscode-remote.vscode-remote-extensionpack"
    "ms-vscode.anycode"
    "ms-vscode.anycode-c-sharp"
    "ms-vscode.anycode-cpp"
    "ms-vscode.anycode-go"
    "ms-vscode.anycode-java"
    "ms-vscode.anycode-kotlin"
    "ms-vscode.anycode-php"
    "ms-vscode.anycode-python"
    "ms-vscode.anycode-rust"
    "ms-vscode.anycode-typescript"
    "ms-vscode.cpptools"
    "ms-vscode.remote-explorer"
    "ms-vscode.vscode-speech"
    "rust-lang.rust-analyzer"
    "thenuprojectcontributors.vscode-nushell-lang"
    "vitest.explorer"
    "yoavbls.pretty-ts-errors"
  ];

  # "publisher.name" を `m.publisher."name"` に解決する。
  # 拡張名にハイフンが含まれていても (vscode-deno など) attrByPath で安全に lookup。
  resolveExt =
    id:
    let
      parts = lib.splitString "." id;
    in
    lib.attrByPath parts (throw "vscode extension not found in nix-vscode-extensions overlay: ${id}") m;
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      extensions = map resolveExt extensionIds;
    };
  };
}
