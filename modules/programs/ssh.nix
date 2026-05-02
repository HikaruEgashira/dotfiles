# SSH config — 1Password SSH agent 統合 (Survivor #3 part 1)
#
# 目的: ~/.ssh/id_* に長期秘密を置かず、Secure Enclave に格納された 1Password
# 管理キーを agent 経由で利用する。enable した時点で:
#   - 全ホスト宛 SSH の認証を 1Password agent に委譲
#   - SSH commit signing は signingkey をここでは触らないので別途
#     `programs.git.settings.user.signingkey` を 1Password 由来 公開鍵に
#     差し替える必要がある (本 PR は SSH 認証層のみ)
#
# 既定 OFF: 1Password app 未インストール環境で IdentityAgent を解決できないと
# 通常 SSH が壊れるため。`hosts/<host>/default.nix` か任意の module で
# `dotfiles.onePasswordSshAgent.enable = true;` を立てて opt-in する。
{
  config,
  lib,
  ...
}:

let
  cfg = config.dotfiles.onePasswordSshAgent;
  agentSocket = "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in
{
  options.dotfiles.onePasswordSshAgent.enable = lib.mkEnableOption "use 1Password SSH agent for all SSH hosts";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      matchBlocks."*" = {
        identityAgent = agentSocket;
      };
    };
  };
}
