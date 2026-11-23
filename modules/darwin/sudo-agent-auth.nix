# 手元 Mac から転送された Secretive 鍵で sudo を通す。鍵が無い・転送が無いときは pam_tid、最後に /etc/pam.d/sudo のパスワードへ落ちる
{ lib, pkgs, ... }:

{
  environment.etc."ssh/sudo_authorized_keys".source = ../../keys/sudo-agent.pub;

  # SSH 越しに reattach すると GUI session の pam_tid が画面側で Touch ID を待ち続けるので ignore_ssh を渡す
  security.pam.services.sudo_local.text = lib.mkForce ''
    auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
    auth       sufficient     ${pkgs.pam_rssh}/lib/libpam_rssh.dylib auth_key_file=/etc/ssh/sudo_authorized_keys
    auth       sufficient     pam_tid.so
  '';

  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';
}
