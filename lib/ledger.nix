# Package Ledger — 期限付き複式記帳化のデータ層
#
# 目的: home.packages / Brewfile に並ぶ各エントリに「出所 (source) / 用途 (purpose) /
# 期限 (expires) / 採用理由 (reason)」を付与し、棚卸しを機械化可能にする。
# 詳細: docs/ideation/2026-05-02-secure-fast-lean-dotfiles-ideation.md (Survivor #2)
#
# 利用側は `mkEntry` で 1 エントリを宣言し、`pkgsOf` でビルド可能な package list、
# `metaOf` で audit 用 metadata list を取り出す。
{
  pkgs,
  lib,
}:

let
  # 用途タクソノミ (固定 7 値)。新カテゴリ追加は ADR を要求する想定。
  purposes = [
    "build" # コンパイル・ビルド・CI・テスト基盤
    "edit" # 主要エディタ・コーディング体験を構成
    "ops" # クラウド・インフラ・DB 運用
    "comm" # 連絡・ブラウザ・チャット
    "observe" # 監視・ログ・デバッグ
    "play" # 実験・AI・遊び
    "util" # 横断的に使う小道具
  ];

  validPurpose = p: builtins.elem p purposes;

  mkEntry =
    {
      pkg,
      purpose,
      source ? "nixpkgs",
      expires ? null,
      reason ? "",
    }:
    assert lib.assertMsg (validPurpose purpose)
      "ledger.mkEntry: unknown purpose '${purpose}' (allowed: ${lib.concatStringsSep ", " purposes})";
    {
      inherit
        pkg
        purpose
        source
        expires
        reason
        ;
      name = pkg.pname or pkg.name or "?";
    };

  # entries (list of mkEntry result) → list of derivations
  pkgsOf = entries: map (e: e.pkg) entries;

  # entries → list of plain-attrset metadata (audit 用、derivation を含めない)
  metaOf =
    entries:
    map (e: {
      inherit (e)
        name
        purpose
        source
        expires
        reason
        ;
    }) entries;

  # JSON 表現 (apps.audit が jq に流すため)
  toJSON = entries: builtins.toJSON (metaOf entries);
in
{
  inherit
    mkEntry
    pkgsOf
    metaOf
    toJSON
    purposes
    ;
}
