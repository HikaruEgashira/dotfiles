{
  programs.direnv = {
    enable = true;
    stdlib = builtins.readFile ./direnv/use_secrets.sh;
  };
}
