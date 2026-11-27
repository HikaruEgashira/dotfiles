# 方針と脅威モデル: docs/solutions/secrets/cloudflare-credentials.md。
# Cloudflare の変更は IaC (gh-intel/gh-intel.com 等) の main push から CI が AWS Secrets Manager の token で apply する。
# 端末には長期 API token を置かず、wrangler の OAuth と cloudflared の Access token は host 専用 (sandbox は deny)。
{
  config,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;
in
{
  options.dotfiles.cloudflare.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "wrangler / cloudflared の login を端末に残す。シンクライアントは false にし、Cloudflare の操作は mac-studio 経由でだけ行う";
  };

  config = lib.mkIf (!config.dotfiles.cloudflare.enable) {
    # telemetry 送信用の otel.gh-intel.com の app token と、それを再発行する org session だけ残す
    home.activation.purgeCloudflareSession = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -f "${home}/.config/.wrangler/config/default.toml"
      for f in "${home}"/.cloudflared/*-token; do
        case "$(basename "$f")" in
          otel.gh-intel.com-*|*-org-token) ;;
          *) if [ -e "$f" ]; then run rm -f "$f"; fi ;;
        esac
      done
    '';
  };
}
