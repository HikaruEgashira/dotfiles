_:

{
  imports = [
    ../../modules/darwin/system.nix
    ../../modules/darwin/nix.nix
    ../../modules/darwin/security.nix
    ../../modules/darwin/native-apps.nix
  ];

  networking = {
    hostName = "Mac-Studio";
    localHostName = "Mac-Studio";
    computerName = "Mac Studio";
  };
}
