{
  pkgs,
  lib,
  ...
}:

let
  m = pkgs.vscode-marketplace;

  extensionIds = [
    "anthropic.claude-code"
    "arcticicestudio.nord-visual-studio-code"
    "astral-sh.ty"
    "bierner.markdown-mermaid"
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
    # ms-vscode.cpptools is on the darwin removed list; use anycode-cpp instead
    "ms-vscode.remote-explorer"
    "ms-vscode.vscode-speech"
    "rust-lang.rust-analyzer"
    "thenuprojectcontributors.vscode-nushell-lang"
    "vitest.explorer"
    "yoavbls.pretty-ts-errors"
  ];

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
