{ config, ... }:

let
  zshConfig = import ../settings/zsh-config.nix;
in

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    envExtra = ''
      # Nix daemon (nix-installer PR#714 gates /etc/zshenv behind SSH_CONNECTION)
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';

    profileExtra = ''
      export PATH="$HOME/.local/share/mise/shims:$PATH"
    '';

    shellAliases = {
      c = "code .";
      con = "claude -c continue";
      q = "gh q --";
      rel = "source ~/.zshrc";
      ghq = "gh q";

      say = "mise exec github:HikaruEgashira/say -- say";
    };

    initContent = builtins.concatStringsSep "\n" [
      zshConfig.aliases
      zshConfig.rust
      zshConfig.path
      zshConfig.secrets
      zshConfig.sendClaude
    ];
  };
}
