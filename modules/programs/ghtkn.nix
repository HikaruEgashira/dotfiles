# GitHub 認証を GitHub App `ghtkn-hikae` の user access token (8h) に統一する。
# 背景: 2026-10-31 に個人の REST quota (5000/h) が別ホストの長期 token に毎時食い潰され、
# 全 OAuth / GitHub App 認可を revoke した。長期 token を端末に置かない構成に切り替える。
# token は macOS keychain に入り、`gh` wrapper (lib/package-registry.nix) と
# git credential helper (git.nix) が `ghtkn exec` / `ghtkn git-credential` で取り出す。
# 初回と 8h 毎の再発行は device flow なので `ghtkn auth` を自分の端末で実行する。
# claude sandbox は keychain の読み書き (Mach lookup, $HOME 書込) を許可済み。
_:
{
  xdg.configFile."ghtkn/ghtkn.yaml".text = ''
    # yaml-language-server: $schema=https://raw.githubusercontent.com/suzuki-shunsuke/ghtkn/main/json-schema/ghtkn.json
    # Client ID は秘密ではない (device flow は client secret を使わない)。
    # App: https://github.com/settings/apps/ghtkn-hikae (Device Flow 有効、HikaruEgashira / plenoai / sisaku-security に install)
    apps:
      - name: HikaruEgashira/ghtkn-hikae
        client_id: Iv23li4HDmrucWZqsdP4
  '';

  # ghtkn の keyring backend は Keychain を使うので sandbox 内からも読める。
  # `GHTKN_GITHUB_TOKEN` を export すれば一時的に PAT へ切替できる (configuration.md)。
  home.sessionVariables.GHTKN_APP = "HikaruEgashira/ghtkn-hikae";
}
