{
  imports = [
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/programs/git.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/zsh.nix
    ./home/programs/mcp-servers.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;

  home = {
    username = "hikae";
    homeDirectory = "/Users/hikae";
    stateVersion = "23.11";
    enableNixpkgsReleaseCheck = false;

    file = {
      ".claude/CLAUDE.md".text = ''
        - use simple conventional commits
        - speak japanese
        - 不可逆な操作でない限りは確認を求めず自律的にタスクを完遂してください。
        - 動作確認し期待通りの動作が確認できるまでがあなたのタスクです。
        - use fd, rg instead of find, grep
      '';

      ".claude/settings.json".text = ''
        {
          "$schema": "https://json.schemastore.org/claude-code-settings.json",
          "model": "opus"
        }
      '';
    };
  };
}
