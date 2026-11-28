# GUI 版 (macsys) は Tailscale SSH server を持たないため OSS の tailscaled に置き換える
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # socket を省くと CLI は GUI 版の daemon に繋がり、OSS 側の state も --ssh も GUI 版に向いてしまう
  ts = "${pkgs.tailscale}/bin/tailscale --socket=/var/run/tailscaled.socket";
  jq = "${pkgs.jq}/bin/jq";
  gui = "/Applications/Tailscale.app";
  state = "${ts} status --json 2>/dev/null | ${jq} -r '.BackendState // empty'";

  # GUI 版が残る間は utun と経路を奪い合わないよう userspace で並走させる。SSH は netstack が終端する
  daemon = pkgs.writeShellScript "tailscaled-launch" ''
    if [ -d ${gui} ]; then
      exec ${pkgs.tailscale}/bin/tailscaled --tun=userspace-networking
    fi
    exec ${pkgs.tailscale}/bin/tailscaled
  '';

  # OSS 側が tailnet に載ったのを確認してから GUI 版を外すので、移行中に tailnet から落ちない
  retire = pkgs.writeShellScript "tailscale-gui-retire" ''
    set -u
    [ -d ${gui} ] || exit 0
    [ "$(${state})" = Running ] || exit 0
    ${ts} set --ssh || exit 0
    /usr/sbin/scutil --nc list | /usr/bin/sed -n 's/.*"\(Tailscale[^"]*\)".*/\1/p' | while read -r svc; do
      /usr/sbin/scutil --nc stop "$svc" || true
    done
    /usr/bin/pkill -x Tailscale || true
    /bin/rm -rf ${gui}
    /bin/launchctl kickstart -k system/com.tailscale.tailscaled
  '';
in
{
  options.dotfiles.tailscaleExitNode = lib.mkEnableOption "exit node の広告";

  config = {
    dotfiles.tailscaleGui = false;
    services.tailscale.enable = true;

    launchd.daemons = {
      tailscaled.command = lib.mkForce "${daemon}";
      tailscaled.serviceConfig.KeepAlive = true;
      tailscale-gui-retire.serviceConfig = {
        Label = "dev.egahika.tailscale-gui-retire";
        ProgramArguments = [ "${retire}" ];
        RunAtLoad = true;
        StartInterval = 60;
        StandardOutPath = "/var/log/tailscale-gui-retire.log";
        StandardErrorPath = "/var/log/tailscale-gui-retire.log";
      };
    };

    # 未ログインなら login を開始して承認 URL を出すだけにし、承認後の収束は retire daemon に任せる
    system.activationScripts.postActivation.text = lib.mkAfter ''
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -n "$(${state})" ] && break
        sleep 1
      done
      case "$(${state})" in
        Running) ${ts} set --ssh --advertise-exit-node=${lib.boolToString config.dotfiles.tailscaleExitNode} ;;
        *)
          ${ts} login --ssh --timeout=10s >/dev/null 2>&1 || true
          url=$(${ts} status --json 2>/dev/null | ${jq} -r '.AuthURL // empty')
          echo "tailscale: approve this device at ''${url:-<no AuthURL; see tailscale status>}" >&2
          ;;
      esac
    '';
  };
}
