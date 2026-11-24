# NixOS-WSL のシステム層。ユーザー層は homeConfigurations."hikae@wsl" (./home.nix) が持つ
{
  imports = [ ../../modules/nixos/telemetry.nix ];

  wsl = {
    enable = true;
    defaultUser = "hikae";
  };

  # WSL の session 終了で ssh-agent / ghtkn-agent の user service を止めない
  users.users.hikae.linger = true;

  security.sudo.wheelNeedsPassword = false;

  # upstream の動的リンク binary (Aqua / VS Code Server) を動かす
  programs.nix-ld.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "hikae"
    ];
  };

  # 初回導入時の NixOS-WSL tarball の値に合わせる。上げる前に release notes を確認する (docs/operations.md §6.1)
  system.stateVersion = "26.05";
}
