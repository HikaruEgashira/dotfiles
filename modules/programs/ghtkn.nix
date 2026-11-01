# GitHub 認証を GitHub App `ghtkn-hikae` の user access token (8h) に統一する。
# 背景: 2026-10-31 に個人の REST quota (5000/h) が別ホストの長期 token に毎時食い潰され、
# 全 OAuth / GitHub App 認可を revoke した。長期 token を端末に置かない構成に切り替える。
# token は agent backend が暗号化して保持し、`gh` wrapper (lib/package-registry.nix) と
# git credential helper (git.nix) が `ghtkn exec` / `ghtkn git-credential` で取り出す。
# refresh token は agent backend でしか使えないため、8h 毎の device flow を避けて
# 自動更新するには agent を launchd で常駐させ、login 後に 1 回 unlock する。
# unlock は passphrase を永続化しない設計なので `ghtkn agent unlock --enable-refresh` を手で実行する。
{
  config,
  lib,
  pkgs,
  ...
}:
{
  xdg.configFile."ghtkn/ghtkn.yaml".text = ''
    # yaml-language-server: $schema=https://raw.githubusercontent.com/suzuki-shunsuke/ghtkn/main/json-schema/ghtkn.json
    # Client ID は秘密ではない (device flow は client secret を使わない)。
    # App: https://github.com/settings/apps/ghtkn-hikae (Device Flow 有効、HikaruEgashira / plenoai / sisaku-security に install)
    apps:
      - name: HikaruEgashira/ghtkn-hikae
        client_id: Iv23li4HDmrucWZqsdP4
    backend:
      type: agent
  '';

  # `GHTKN_GITHUB_TOKEN` を export すれば一時的に PAT へ切替できる (configuration.md)。
  home.sessionVariables.GHTKN_APP = "HikaruEgashira/ghtkn-hikae";

  # 人間が叩く唯一の認証入口。agent の起動と unlock を吸収して device flow へ入る
  home.file.".local/bin/ghauth" = {
    text = builtins.readFile ./ghtkn/ghauth.sh;
    executable = true;
  };

  # `ghtkn agent stop` は exit 0 なので SuccessfulExit=false で crash だけ再起動する
  launchd.agents = lib.mkIf (pkgs ? ghtkn) {
    ghtkn-agent = {
      enable = true;
      config = {
        Label = "dev.egahika.ghtkn-agent";
        ProgramArguments = [
          "${pkgs.ghtkn}/bin/ghtkn"
          "agent"
          "start"
        ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/ghtkn-agent.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/ghtkn-agent.log";
      };
    };
  };
}
