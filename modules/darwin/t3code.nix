# T3 Code は policy の telemetry=false で PostHog 解析・relay trace・desktop 計測をまとめて止め、ユーザー設定では戻せない
{ lib, ... }:
let
  dir = "/Library/Application Support/T3Code";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    install -d -m 755 -o root -g wheel "${dir}"
    install -m 644 -o root -g wheel ${../programs/t3code/policy.json} "${dir}/policy.json"
  '';
}
