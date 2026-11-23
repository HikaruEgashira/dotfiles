# 手元 Mac から転送された Secretive 鍵で sudo を通す。転送が無ければ pam_unix のパスワードへ落ちる
_: {
  # 利用者が書き換えられる場所の鍵を信頼すると sudo が乗っ取られるので、root 所有の実ファイルに複製する
  environment.etc."ssh/sudo_authorized_keys" = {
    source = ../../keys/sudo-agent.pub;
    mode = "0444";
  };

  security.pam = {
    sshAgentAuth = {
      enable = true;
      authorizedKeysFiles = [ "/etc/ssh/sudo_authorized_keys" ];
    };
    services.sudo.sshAgentAuth = true;
  };
}
