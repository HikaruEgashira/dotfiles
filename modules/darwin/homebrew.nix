_:

{
  # nixpkgs に無い / nix 化すると版 pin が GUI の auto-update と噛み合わないものだけを残す
  homebrew = {
    enable = true;
    user = "hikae";

    # activation は brew を upgrade/cleanup しない (差分は brew 側の auto-update に任せる)
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };

    taps = [
      "higgsfield-ai/tap" # higgsfield (nixpkgs 無し)
      "plenoai/tap" # pleno-dlp (nixpkgs 無し)
      "sisaku-security/sisakulint" # sisakulint (nixpkgs 無し)
      "steipete/tap" # oracle (nixpkgs 無し)
      "withgraphite/tap" # graphite (nixpkgs 無し)
    ];

    brews = [
      "arm-none-eabi-gcc" # nixpkgs の版が古い
      "googleworkspace-cli" # nixpkgs 無し
      "higgsfield-ai/tap/higgsfield"
      "icarus-verilog" # nixpkgs 無し
      "plenoai/tap/pleno-dlp"
      "ripgrep" # codex (cask) が依存
      "sisaku-security/sisakulint/sisakulint"
      "steipete/tap/oracle"
      "withgraphite/tap/graphite"
    ];

    casks = [
      "discord" # GUI: nix は版を pin し LaunchServices を奪う
      "slack" # GUI: 同上
      "raycast" # GUI: 同上
      "codex" # GUI: nixpkgs の codex は CLI で別物
      "ghostty"
      "obs" # nix の obs-studio は linux-only
      "tailscale-app" # nixpkgs 無し (GUI)
      "windows-app" # nixpkgs 無し (GUI)
    ];

    masApps."Xcode" = 497799835;
  };
}
