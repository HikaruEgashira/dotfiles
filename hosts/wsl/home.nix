{
  imports = [
    ../linux/home.nix
    ./windows.nix
    ./ime.nix
  ];

  # この端末で発行した署名鍵 (~/.ssh/id_ed25519_sign)。公開鍵は git.nix の allowedSigners にも載せる
  programs.git.signing.key = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMgH2JVbVWM1JEQXafU+Zqeb9Ta1/YBkjPvnUbi8+Ff";
}
