# Host-specific module — primary host (`hikae`).
#
# 設計: `home.nix` が universal な base、`hosts/<host>/default.nix` が
# host 固有 override を担う。primary host は base と同一なので空。
# 例: 業務マシンを増やす時は `hosts/hikae@work/default.nix` を新規作成し、
# `flake.nix.hosts` 表に追加するだけ。base 側を分岐させない。
_: {
  # 例: home.sessionVariables.HTTP_PROXY = "http://corp-proxy:3128";
  # 例: home.activation.lockScreenAfterIdle = ...;
}
