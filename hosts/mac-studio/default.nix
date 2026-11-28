_:

{
  imports = [
    ../../modules/darwin/system.nix
    ../../modules/darwin/nix.nix
    ../../modules/darwin/security.nix
    ../../modules/darwin/native-apps.nix
    ../../modules/darwin/claude-code.nix
    ../../modules/darwin/t3code.nix
    ../../modules/darwin/telemetry.nix
    ../../modules/darwin/tailscale-ssh.nix
    ../../modules/darwin/fleet.nix
    ../../modules/darwin/sudo-agent-auth.nix
  ];

  # 外出先のスマホと macbook-air の通信を自宅回線から出す。低区分の ms-a2 は経由させない
  dotfiles.tailscaleExitNode = true;

  networking = {
    hostName = "Mac-Studio";
    localHostName = "Mac-Studio";
    computerName = "Mac Studio";
  };
}
