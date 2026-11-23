_:

{
  imports = [
    ../../modules/darwin/system.nix
    ../../modules/darwin/nix.nix
    ../../modules/darwin/security.nix
    ../../modules/darwin/native-apps.nix
    ../../modules/darwin/claude-code.nix
    ../../modules/darwin/tailscale-ssh.nix
    ../../modules/darwin/sudo-agent-auth.nix
  ];

  networking = {
    hostName = "Mac-Studio";
    localHostName = "Mac-Studio";
    computerName = "Mac Studio";
  };
}
