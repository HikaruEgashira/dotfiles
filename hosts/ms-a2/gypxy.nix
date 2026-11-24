# gypxy hub は loopback だけで待ち受け、tailnet には公開しない (docs/security/threat-model.md F2)
_: {
  # user service をログインなしで起動しておく
  users.users.hikae.linger = true;
}
