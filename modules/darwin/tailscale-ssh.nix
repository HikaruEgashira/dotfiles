# GUI 版 (macsys) は Tailscale SSH server を持たないため OSS の tailscaled に置き換える
{ lib, pkgs, ... }:

{
  dotfiles.tailscaleGui = false;
  services.tailscale.enable = true;

  # 未ログインの初回は失敗するので、`sudo tailscale up --ssh` 後の再適用で収束させる
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
      ${pkgs.tailscale}/bin/tailscale set --ssh
    else
      echo "tailscale: not logged in; run 'sudo tailscale up --ssh'" >&2
    fi
  '';
}
